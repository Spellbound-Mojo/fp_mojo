"""State: deferred computations threading an owned state through any base Monad.

A run consumes the state and returns the base carrier of Tuple[value, state].
Each operation is one struct whose run delegates to the base family.
"""
from fp.algebra._admission import _CarrierBind, _CarrierCombine
from std.builtin.rebind import rebind_var, rebind, downcast
from std.utils import Variant
from fp.algebra.errors import _Continue
from fp.algebra.protocols import (ApplicativeError, ErrorMapping, _UnaryView, Monad, _Accumulate, _LiveAccumulator, _BindFirst, _Lazy, _Item, _iterator, _next_item, _start_as)
from fp.algebra.instances import IdentityFamily
from fp.callables.protocols import (BorrowCallContract, UnaryContract, BinaryContract, ThunkContract, Unary, OnceUnary, MutableUnary, Binary, MutableBinary)
from fp.callables.invoke import call_once, call_repeated, RepeatableUnary, RepeatableBinary
from fp.callables._receiver import _binary_repeated_as, _unary_once_as
from std.memory import MaybeUninit
from fp.callables.products import _take_pair, _WithSecond as _WithState
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from .protocols import Stateful, Local, Listen, _CarrierOp, _LocalLifting, StateAction, StateFamily, _EndpointCompatible, _FAMILY_MISMATCH, _CHOICE_FAMILY, _CHOICE_VALUE
from ._adapt import _op_as, _state_run_as, _map_as, _flat_map_as

from ._transport import _BimapOp, _LocalOp, _ListenOp, _ListenMapped, _ListenPair


comptime _Action[V: Movable & Deinitable] = downcast[V, StateAction]


@fieldwise_init
struct _StatePure[M: Monad, S: Movable & Deinitable, T: Movable & Deinitable](StateAction, Copyable where conforms_to(T, Copyable)):
    var value: Self.T
    comptime Family = StateT[Self.M, Self.S]
    comptime State = Self.S
    comptime Value = Self.T
    comptime Out = Self.M.Pure[Tuple[Self.T, Self.S]]
    def run(deinit self, var state: Self.State) -> Self.Out:
        return Self.M.pure(Tuple(self.value^, state^))


@fieldwise_init
struct _StateFail[M: Monad, S: Movable & Deinitable, A: Movable & Deinitable](StateAction, Copyable where conforms_to(downcast[M, ApplicativeError].Failure, Copyable)):
    """Owned-state boundary for a deferred base failure; the state is dropped."""
    comptime Errors = downcast[Self.M, ApplicativeError]
    var error: Self.Errors.Failure
    comptime Family = StateT[Self.M, Self.S]
    comptime State = Self.S
    comptime Value = Self.A
    comptime Out = Self.Errors.Failed[Tuple[Self.A, Self.S]]
    comptime Error = Self.Errors.FailError[Tuple[Self.A, Self.S]]
    def run(deinit self, var state: Self.State) raises Self.Error -> Self.Out:
        return Self.Errors.fail[Tuple[Self.A, Self.S]](self.error^)


@fieldwise_init
struct _StateGet[M: Monad, S: Copyable & Deinitable](StateAction, Copyable, Defaultable):
    comptime Family = StateT[Self.M, Self.S]
    comptime State = Self.S
    comptime Value = Self.S
    comptime Out = Self.M.Pure[Tuple[Self.S, Self.S]]
    def run(deinit self, var state: Self.State) -> Self.Out:
        var copy = state.copy()
        return Self.M.pure(Tuple(copy^, state^))


@fieldwise_init
struct _StateModify[M: Monad, S: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    StateAction, Copyable where conforms_to(F, Copyable)
):
    var function: Self.F
    comptime Family = StateT[Self.M, Self.S]
    comptime State = Self.S
    comptime Value = NoneType
    comptime Out = Self.M.Pure[Tuple[NoneType, Self.S]]
    comptime Error = Self.F.Error
    def run(deinit self, var state: Self.State) raises Self.Error -> Self.Out:
        comptime assert Self.F.Arg == Self.S and Self.F.Out == Self.S, "modify: the callback must map the state to a new state"
        var updated = rebind_var[Self.S](call_once(self.function^, rebind_var[Self.F.Arg](state^)))
        var nothing: NoneType = None
        return Self.M.pure(Tuple(nothing, updated^))


@fieldwise_init
struct _StateEndpoint[M: Monad, S: Movable & Deinitable, T: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    StateAction, Copyable where conforms_to(F, Copyable)
):
    """A native endpoint consuming the state and returning a base carrier."""
    var function: Self.F
    comptime Family = StateT[Self.M, Self.S]
    comptime State = Self.S
    comptime Value = Self.T
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error
    def run(deinit self, var state: Self.State) raises Self.Error -> Self.Out:
        comptime assert Self.F.Arg == Self.S, "action: the endpoint must consume the State"
        return call_once(self.function^, rebind_var[Self.F.Arg](state^))


@fieldwise_init
struct _StateLift[M: Monad, S: Movable & Deinitable, V: Movable & Deinitable](StateAction, Copyable where conforms_to(V, Copyable)):
    """A base carrier paired with the unchanged state."""
    var value: Self.V
    comptime Family = StateT[Self.M, Self.S]
    comptime State = Self.S
    comptime Value = Self.M.Element[Self.V]
    comptime Pair = _WithState[Self.Value, Self.S]
    comptime Out = Self.M.Mapped[Self.V, Self.Pair]
    comptime Error = Self.M.MapError[Self.V, Self.Pair]
    def run(deinit self, var state: Self.State) raises Self.Error -> Self.Out:
        return Self.M.map(Self.Pair(state^), self.value^)


@fieldwise_init
struct _MapFirst[F: UnaryContract & Movable & Deinitable, S: Movable & Deinitable](
    OnceUnary, MutableUnary where RepeatableUnary[F], Copyable where conforms_to(F, Copyable)
):
    """Map the value of a (value, state) pair."""
    var function: Self.F
    comptime Arg = Tuple[Self.F.Arg, Self.S]
    comptime Out = Tuple[Self.F.Out, Self.S]
    comptime Error = Self.F.Error
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        var value_slot = MaybeUninit[Self.F.Arg]()
        var state_slot = MaybeUninit[Self.S]()
        _take_pair(arg^, value_slot, state_slot)
        var value_part = value_slot^.unsafe_assume_init()
        var state_part = state_slot^.unsafe_assume_init()
        var value = call_once(self.function^, value_part^)
        return Tuple(value^, state_part^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F]
        var value_slot = MaybeUninit[Self.F.Arg]()
        var state_slot = MaybeUninit[Self.S]()
        _take_pair(arg^, value_slot, state_slot)
        var value_part = value_slot^.unsafe_assume_init()
        var state_part = state_slot^.unsafe_assume_init()
        var value = call_repeated(self.function, value_part^)
        return Tuple(value^, state_part^)


@fieldwise_init
struct _StateContinue[I: AnyType, F: UnaryContract & Movable & Deinitable, S: Movable & Deinitable, recover: Bool = False](
    OnceUnary, MutableUnary where RepeatableUnary[F] and (not recover or conforms_to(S, Copyable)),
    Copyable where conforms_to(F, Copyable) and conforms_to(S if recover else NoneType, Copyable)
):
    """Run F's action on the carried state, or on the saved recovery input.

    Repeated recovery copies the saved input for each error branch. A single
    call transfers that input; ordinary bind still accepts move-only state.
    """
    var function: Self.F
    comptime Saved = Self.S if Self.recover else NoneType
    var initial: Self.Saved
    comptime Action = _Action[Self.F.Out]
    comptime Arg = Self.F.Arg if Self.recover else Tuple[Self.F.Arg, Self.S]
    comptime Out = Self.Action.Out
    comptime Error = _CommonError[Self.F.Error, Self.Action.Error]
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert Self.Action.Family == Self.I, _FAMILY_MISMATCH
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error] and _ErrorCompatible[Self.Error, Self.Action.Error]
        var value_part: Self.F.Arg
        var state_part: Self.S
        comptime if Self.recover:
            value_part = rebind_var[Self.F.Arg](arg^)
            state_part = rebind_var[Self.S](self.initial^)
        else:
            var value_slot = MaybeUninit[Self.F.Arg]()
            var state_slot = MaybeUninit[Self.S]()
            _take_pair(rebind_var[Tuple[Self.F.Arg, Self.S]](arg^), value_slot, state_slot)
            value_part = value_slot^.unsafe_assume_init()
            state_part = state_slot^.unsafe_assume_init()
        var action = rebind_var[Self.Action](_unary_once_as[Self.Error](self.function^, value_part^))
        return _state_run_as[Self.Error](action^, rebind_var[Self.Action.State](state_part^))

    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F]
        comptime View = _UnaryView[Self.F, origin_of(self.function)]
        comptime Next = _StateContinue[Self.I, View, Self.S, Self.recover]
        comptime assert Next.Arg == Self.Arg and Next.Out == Self.Out
        comptime assert _ErrorCompatible[Self.Error, Next.Error]
        var initial: Next.Saved
        comptime if Self.recover:
            comptime C = downcast[Self.S, Copyable & Deinitable]
            initial = rebind_var[Next.Saved](rebind[C](self.initial).copy())
        else:
            initial = rebind_var[Next.Saved](None)
        return rebind_var[Self.Out](_unary_once_as[Self.Error](Next(View(Pointer(to=self.function)), initial^), rebind_var[Next.Arg](arg^)))


@fieldwise_init
struct _StatePrepare[I: AnyType, M: Monad, S: Movable & Deinitable, F: BinaryContract & Movable & Deinitable,
                     G: ThunkContract & Movable & Deinitable](
    OnceUnary, MutableUnary where conforms_to(F, Copyable) and conforms_to(G.Out, Copyable)
):
    """After the left value: produce the right computation once, run it on the
    left branch's state and combine. Repeated branches copy the produced
    computation and the callback."""
    var function: Self.F
    var right: _Lazy[Self.G]
    comptime Action = _Action[Self.G.Out]
    comptime Combine = _MapFirst[_BindFirst[Self.F], Self.S]
    comptime Arg = Tuple[Self.F.First, Self.S]
    comptime Out = Self.M.Mapped[Self.Action.Out, Self.Combine]
    comptime Error = _CommonError[Self.G.Error, _CommonError[Self.Action.Error, Self.M.MapError[Self.Action.Out, Self.Combine]]]
    @staticmethod
    def _combine(var action: Self.Action, var function: Self.F, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert Self.Action.Family == Self.I, _FAMILY_MISMATCH
        comptime assert _ErrorCompatible[Self.Error, Self.Action.Error] and _ErrorCompatible[Self.Error, Self.M.MapError[Self.Action.Out, Self.Combine]]
        var value_slot = MaybeUninit[Self.F.First]()
        var state_slot = MaybeUninit[Self.S]()
        _take_pair(arg^, value_slot, state_slot)
        var value_part = value_slot^.unsafe_assume_init()
        var state_part = state_slot^.unsafe_assume_init()
        var based = _state_run_as[Self.Error](action^, rebind_var[Self.Action.State](state_part^))
        return _map_as[Self.Error, Self.M](Self.Combine(_BindFirst[Self.F](function^, value_part^)), based^)
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.Error, Self.G.Error]
        var action = rebind_var[Self.Action](self.right^.take[Self.Error]())
        return Self._combine(action^, self.function^, arg^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert conforms_to(Self.F, Copyable), "map2: repeated branches copy the callback and the right computation"
        comptime assert _ErrorCompatible[Self.Error, Self.G.Error]
        var action: Self.Action
        try:
            action = rebind_var[Self.Action](self.right.copy_value())
        except error:
            _propagate_error[Self.Error](error^)
        comptime C = downcast[Self.F, Copyable & Deinitable]
        var function = rebind_var[Self.F](rebind[C](self.function).copy())
        return Self._combine(action^, function^, arg^)


@fieldwise_init
struct _StateMap[M: Monad, S: Movable & Deinitable, A: StateAction, F: UnaryContract & Movable & Deinitable](
    StateAction, Copyable where conforms_to(A, Copyable) and conforms_to(F, Copyable)
):
    var source: Self.A
    var function: Self.F
    comptime Family = StateT[Self.M, Self.S]
    comptime State = Self.S
    comptime Value = Self.F.Out
    comptime Step = _MapFirst[Self.F, Self.S]
    comptime Out = Self.M.Mapped[Self.A.Out, Self.Step]
    comptime Error = _CommonError[Self.A.Error, Self.M.MapError[Self.A.Out, Self.Step]]
    def run(deinit self, var state: Self.State) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.Error, Self.A.Error] and _ErrorCompatible[Self.Error, Self.M.MapError[Self.A.Out, Self.Step]]
        var base = _state_run_as[Self.Error](self.source^, rebind_var[Self.A.State](state^))
        return _map_as[Self.Error, Self.M](Self.Step(self.function^), base^)


@fieldwise_init
struct _StateBind[M: Monad, S: Movable & Deinitable, A: StateAction, F: UnaryContract & Movable & Deinitable, recover: Bool = False](
    StateAction, Copyable where conforms_to(A, Copyable) and conforms_to(F, Copyable)
):
    var source: Self.A
    var function: Self.F
    comptime Family = StateT[Self.M, Self.S]
    comptime State = Self.S
    comptime Value = _Action[Self.F.Out].Value
    comptime Next = _StateContinue[Self.Family, Self.F, Self.S, Self.recover]
    comptime Operation = _Continue[Self.M, Self.recover]
    comptime Out = Self.Operation.Out[Self.A.Out, Self.Next]
    comptime Error = _CommonError[Self.A.Error, Self.Operation.Error[Self.A.Out, Self.Next]]
    def run(deinit self, var state: Self.State) raises Self.Error -> Self.Out:
        comptime assert _Action[Self.F.Out].Family == Self.Family, _FAMILY_MISMATCH
        comptime assert _ErrorCompatible[Self.Error, Self.A.Error] and _ErrorCompatible[Self.Error, Self.Operation.Error[Self.A.Out, Self.Next]]
        var source_state: Self.S
        var saved: Self.Next.Saved
        comptime if Self.recover:
            comptime assert conforms_to(Self.S, Copyable), "StateT recovery requires Copyable input state"
            comptime C = downcast[Self.S, Copyable & Deinitable]
            source_state = rebind_var[Self.S](rebind[C](state).copy())
            saved = rebind_var[Self.Next.Saved](state^)
        else:
            source_state = state^
            saved = rebind_var[Self.Next.Saved](None)
        var base = _state_run_as[Self.Error](self.source^, rebind_var[Self.A.State](source_state^))
        return Self.Operation.apply[Self.Error](Self.Next(self.function^, saved^), base^)


@fieldwise_init
struct _StateCombine[M: Monad, S: Movable & Deinitable, A: StateAction, F: BinaryContract & Movable & Deinitable,
                     G: ThunkContract & Movable & Deinitable](
    StateAction, Copyable where conforms_to(A, Copyable) and conforms_to(F, Copyable) and conforms_to(G, Copyable)
):
    """The right computation runs on the state the left one produced."""
    var source: Self.A
    var function: Self.F
    var right: Self.G
    comptime Family = StateT[Self.M, Self.S]
    comptime State = Self.S
    comptime Value = Self.F.Out
    comptime Next = _StatePrepare[Self.Family, Self.M, Self.S, Self.F, Self.G]
    comptime Out = Self.M.Bound[Self.A.Out, Self.Next]
    comptime Error = _CommonError[Self.A.Error, Self.M.BindError[Self.A.Out, Self.Next]]
    def run(deinit self, var state: Self.State) raises Self.Error -> Self.Out:
        comptime assert _Action[Self.G.Out].Family == Self.Family, _FAMILY_MISMATCH
        comptime assert _ErrorCompatible[Self.Error, Self.A.Error] and _ErrorCompatible[Self.Error, Self.M.BindError[Self.A.Out, Self.Next]]
        var base = _state_run_as[Self.Error](self.source^, rebind_var[Self.A.State](state^))
        var next = Self.Next(self.function^, _Lazy[Self.G](self.right^))
        return _flat_map_as[Self.Error, Self.M](next^, base^)


struct _StateLive[K: _LiveAccumulator, S: Movable & Deinitable](_LiveAccumulator):
    comptime Acc = Tuple[Self.K.Acc, Self.S]
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        return Self.K.live(acc[0])


@fieldwise_init
struct _FoldState[K: _Accumulate, S: Movable & Deinitable](
    OnceUnary, MutableUnary where conforms_to(K.Acc, Copyable)
):
    """Combine a produced value into the branch's accumulator, keeping the new state."""
    var acc: Self.K.Acc
    comptime Arg = Tuple[Self.K.Item, Self.S]
    comptime Out = Tuple[Self.K.Acc, Self.S]
    comptime Error = Self.K.Error
    @staticmethod
    def _fold(var acc: Self.K.Acc, var arg: Self.Arg) raises Self.Error -> Self.Out:
        var value_slot = MaybeUninit[Self.K.Item]()
        var state_slot = MaybeUninit[Self.S]()
        _take_pair(arg^, value_slot, state_slot)
        var value_part = value_slot^.unsafe_assume_init()
        var state_part = state_slot^.unsafe_assume_init()
        var combined = Self.K.combine(acc^, value_part^)
        return Tuple(combined^, state_part^)
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        return Self._fold(self.acc^, arg^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime C = downcast[Self.K.Acc, Copyable & Deinitable]
        return Self._fold(rebind_var[Self.K.Acc](rebind[C](self.acc).copy()), arg^)


@fieldwise_init
struct _StateTraverseStep[I: AnyType, M: Monad, S: Movable & Deinitable, K: _Accumulate, A: StateAction](Binary, Copyable, Defaultable):
    """Run a prepared action on one live branch; the shared driver owns liveness
    and copies the action only when the base invokes the step repeatedly."""
    comptime First = Tuple[Self.K.Acc, Self.S]
    comptime Second = Self.A
    comptime Fold = _FoldState[Self.K, Self.S]
    comptime Out = Self.M.Mapped[Self.A.Out, Self.Fold]
    comptime Error = _CommonError[Self.A.Error, Self.M.MapError[Self.A.Out, Self.Fold]]
    def call(self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        comptime assert Self.A.Family == Self.I, _FAMILY_MISMATCH
        comptime assert Self.A.Value == Self.K.Item, "traverse: every produced computation must have the accumulated value type"
        comptime assert Self.M.Pure[Self.First] == Self.Out, "traverse: State traversal needs a base whose carrier type stays the same across steps"
        comptime assert _ErrorCompatible[Self.Error, Self.A.Error] and _ErrorCompatible[Self.Error, Self.M.MapError[Self.A.Out, Self.Fold]]
        var value_slot = MaybeUninit[Self.K.Acc]()
        var state_slot = MaybeUninit[Self.S]()
        _take_pair(first^, value_slot, state_slot)
        var value_part = value_slot^.unsafe_assume_init()
        var state_part = state_slot^.unsafe_assume_init()
        var based = _state_run_as[Self.Error](second^, rebind_var[Self.A.State](state_part^))
        return _map_as[Self.Error, Self.M](Self.Fold(value_part^), based^)


@fieldwise_init
struct _StateLoop[M: Monad, S: Movable & Deinitable, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable,
                  K: _Accumulate](
    StateAction, Copyable where conforms_to(V, Copyable) and conforms_to(F, Copyable)
):
    """Prepare each computation once and bind it through the shared dependent loop."""
    var source: Self.V
    var function: Self.F
    comptime Family = StateT[Self.M, Self.S]
    comptime State = Self.S
    comptime Produced = _Action[Self.F.Out]
    comptime Value = Self.K.Acc
    comptime Policy = _StateLive[Self.K, Self.S]
    comptime Step = _StateTraverseStep[Self.Family, Self.M, Self.S, Self.K, Self.Produced]
    comptime Out = Self.M.Pure[Self.Policy.Acc]
    comptime Error = _CommonError[Self.K.Error, Self.M._FoldError[Self.V, Self.F, Self.Step, Self.Policy]]
    def run(deinit self, var state: Self.State) raises Self.Error -> Self.Out:
        comptime E = Self.Error
        comptime assert Self.Produced.Family == Self.Family, _FAMILY_MISMATCH
        # Preserve traversal's existing stable-base contract; the dependent
        # fold hook additionally serves folds whose target is State itself.
        comptime assert Self.M._Folded[Self.V, Self.F, Self.Step, Self.Policy] == Self.Out, "traverse: State traversal needs a base whose carrier type stays the same across steps"
        comptime assert _ErrorCompatible[E, Self.K.Error]
        var initial = Tuple(_start_as[E, Self.K](), state^)
        return Self._fold(self.function^, initial^, self.source^)
    @staticmethod
    def _fold(var function: Self.F, var initial: Self.Policy.Acc, var source: Self.V) raises Self.Error -> Self.Out:
        comptime E = Self.Error
        try:
            return rebind_var[Self.Out](Self.M._fold[Self.V, Self.F, Self.Step, Self.Policy](function^, Self.Step(), initial^, source^))
        except error:
            comptime assert _ErrorCompatible[E, type_of(error)]
            _propagate_error[E](error^)


@fieldwise_init
struct _StateFoldStep[I: AnyType, S: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](MutableBinary):
    """A dependent step carries its accumulator and the State state separately."""
    var function: Self.F
    comptime First = Tuple[Self.F.First, Self.S]
    comptime Second = Self.F.Second
    comptime Action = _Action[Self.F.Out]
    comptime Out = Self.Action.Out
    comptime Error = _CommonError[Self.F.Error, Self.Action.Error]
    def call_mut(mut self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        comptime assert RepeatableBinary[Self.F] and Self.Action.Family == Self.I
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error] and _ErrorCompatible[Self.Error, Self.Action.Error]
        var acc_slot = MaybeUninit[Self.F.First]()
        var state_slot = MaybeUninit[Self.S]()
        _take_pair(first^, acc_slot, state_slot)
        var acc = acc_slot^.unsafe_assume_init()
        var state = state_slot^.unsafe_assume_init()
        var action = rebind_var[Self.Action](_binary_repeated_as[Self.Error](self.function, acc^, second^))
        return _state_run_as[Self.Error](action^, rebind_var[Self.Action.State](state^))


@fieldwise_init
struct _StateFold[M: Monad, S: Movable & Deinitable, V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator](StateAction):
    var prepare: Self.P
    var function: Self.F
    var initial: Self.K.Acc
    var source: Self.V
    comptime Family = StateT[Self.M, Self.S]
    comptime State = Self.S
    comptime Value = Self.K.Acc
    comptime Step = _StateFoldStep[Self.Family, Self.S, Self.F]
    comptime Policy = _StateLive[Self.K, Self.S]
    comptime Out = Self.M._Folded[Self.V, Self.P, Self.Step, Self.Policy]
    comptime Error = Self.M._FoldError[Self.V, Self.P, Self.Step, Self.Policy]
    def run(deinit self, var state: Self.State) raises Self.Error -> Self.Out:
        return Self.M._fold[Self.V, Self.P, Self.Step, Self.Policy](self.prepare^, Self.Step(self.function^), Tuple(self.initial^, state^), self.source^)


@fieldwise_init
struct _StateChoice[M: Monad, A: StateAction, B: StateAction](
    StateAction, Copyable where conforms_to(A, Copyable) and conforms_to(B, Copyable)
):
    """One of two computations of one State family. Running it runs the
    selected branch; the base joins the two branches' carriers."""
    var value: Variant[Self.A, Self.B]
    comptime Family = Self.A.Family
    comptime State = Self.A.State
    comptime Value = Self.A.Value
    comptime Out = Self.M._Joined[Self.A.Out, Self.B.Out]
    comptime Error = _CommonError[Self.A.Error, Self.B.Error]
    def run(deinit self, var state: Self.State) raises Self.Error -> Self.Out:
        comptime assert Self.B.Family == Self.A.Family and Self.B.State == Self.A.State, _CHOICE_FAMILY
        comptime assert Self.B.Value == Self.A.Value, _CHOICE_VALUE
        comptime assert _ErrorCompatible[Self.Error, Self.A.Error] and _ErrorCompatible[Self.Error, Self.B.Error]
        var value = self.value^
        if value.isa[Self.A]():
            var left = _state_run_as[Self.Error](value^.unsafe_unwrap[Self.A](), rebind_var[Self.A.State](state^))
            return Self.M._join_left[Self.A.Out, Self.B.Out](left^)
        var right = _state_run_as[Self.Error](value^.unsafe_unwrap[Self.B](), rebind_var[Self.B.State](state^))
        return Self.M._join_right[Self.A.Out, Self.B.Out](right^)


@fieldwise_init
struct _StateHoist[A: Movable & Deinitable, S: StateAction, H: _CarrierOp, Target: AnyType = S.Family](
    StateAction, Copyable where conforms_to(S, Copyable) and conforms_to(H, Copyable)
):
    """Run the original source, then apply an operation into the admitted family."""
    var source: Self.S
    var operation: Self.H
    comptime Family = Self.Target
    comptime State = Self.S.State
    comptime Value = Self.A
    comptime Out = Self.H.Applied[Self.S.Out]
    comptime Error = _CommonError[Self.S.Error, Self.H.Error[Self.S.Out]]
    def run(deinit self, var state: Self.State) raises Self.Error -> Self.Out:
        comptime E = Self.Error
        comptime assert Self.H.Compatible[Self.S.Out]
        comptime assert _ErrorCompatible[E, Self.S.Error] and _ErrorCompatible[E, Self.H.Error[Self.S.Out]]
        var base = _state_run_as[E](self.source^, state^)
        return _op_as[E](self.operation^, base^)


struct StateT[M: Monad, S: Movable & Deinitable](StateFamily, Stateful, _LocalLifting, ApplicativeError where conforms_to(M, ApplicativeError) and conforms_to(S, Copyable), ErrorMapping where conforms_to(M, ErrorMapping)):
    """State over the base Monad `M`: a computation consumes a state `S` when run and returns an `M` carrier of `(value, state)`.

    Computations are built as for `ReaderT` and run with `run`. Traversal is one
    loop: it checks that the base carrier still has a live branch, pulls one
    item, calls the producer once, and binds the prepared computation across
    the live branches, each on its own state. A failed, absent or empty carrier
    stops producer calls and source pulls. The base carrier's type must stay
    the same across steps, as it does for Identity, Optional, Result and List;
    a deferred base is a compile error there.

    Stored-error recovery is available when M implements ApplicativeError
    and S is Copyable. Ordinary State operations still accept move-only state.

    Parameters:
        M: The base Monad.
        S: The state's type.
    """
    comptime Family = Self
    comptime GetAvailable = conforms_to(Self.S, Copyable)
    comptime Got = _StateGet[Self.M, downcast[Self.S, Copyable & Deinitable]]
    comptime GetError = Never
    comptime ModifyCompatible[F: UnaryContract & Movable & Deinitable] = F.Arg == Self.S and F.Out == Self.S
    comptime Modified[F: UnaryContract & Movable & Deinitable] = _StateModify[Self.M, Self.S, F]
    comptime ModifyError[F: UnaryContract & Movable & Deinitable] = Never

    @staticmethod
    def get() -> Self.Got:
        """Construct a read of this layer's copyable state.

        Returns:
            A deferred state read; construction does not copy the state.
        """
        comptime assert Self.GetAvailable, "get: state must be Copyable"
        return Self.Got()

    @staticmethod
    def modify[F: UnaryContract & Movable & Deinitable](var f: F) -> Self.Modified[F]:
        """Construct an update of this layer's state using the State kernel.

        Parameters:
            F: A consuming state-to-state callback.

        Args:
            f: The transformation, consumed.

        Returns:
            A deferred update with NoneType payload.
        """
        comptime assert Self.ModifyCompatible[F], "modify: the callback must map the state to a new state"
        return Self.Modified[F](f^)

    comptime _HoistCompatible[V: Movable & Deinitable, H: _CarrierOp] = Self.CarrierCompatible[V] and H.Compatible[_Action[V].Out] and _ErrorCompatible[_CommonError[_Action[V].Error, H.Error[_Action[V].Out]], H.Error[_Action[V].Out]]
    comptime _HoistedAs[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp, Target: StateFamily] = _StateHoist[A, _Action[V], H, Target]
    comptime _Hoisted[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp] = Self._HoistedAs[A,V,H,Self]
    comptime _HoistError[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp] = Never
    comptime _Listening[C: Listen, A: Movable & Deinitable] = _ListenMapped[C, Tuple[A, Self.S], _ListenPair[Self.S, A, C.Log.Value, False]]
    @staticmethod
    def _hoist[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp](var op: H, var value: V) -> Self._Hoisted[A, V, H]:
        return Self._hoist_as[A,V,H,Self](op^,value^)

    @staticmethod
    def _hoist_as[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp, Target: StateFamily](var op: H, var value: V) -> Self._HoistedAs[A,V,H,Target]:
        return Self._HoistedAs[A,V,H,Target](rebind_var[_Action[V]](value^),op^)

    comptime _ScopeCompatible[C: Local, V: Movable & Deinitable] = Self.CarrierCompatible[V] and C.LocalCompatible[_Action[V].Out]
    comptime _Scoped[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = Self._Hoisted[Self.Element[V], V, _LocalOp[C, F]]
    comptime _ScopeError[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = Never

    @staticmethod
    def _scope[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable](var f: F, var value: V) -> Self._Scoped[C, V, F]:
        """Transport a selected base scope through State.

        Parameters:
            C: The selected base Local capability.
            V: This State family's computation type.
            F: The selected environment transformation type.

        Args:
            f: The transformation, consumed.
            value: The computation, consumed.

        Returns:
            A State action that scopes its produced base carrier when run.
        """
        comptime assert C.Family == Self.Base and Self._ScopeCompatible[C, V]
        return Self._hoist[Self.Element[V]](_LocalOp[C, F](f^), value^)

    comptime _Errors = downcast[Self.M, ApplicativeError]
    comptime _Mapping = downcast[Self.M, ErrorMapping]
    # Mapping does not require recovery. Both capabilities share one Failure
    # when present; an error-mapping-only base uses its own exact witness.
    comptime Failure = Self._Errors.Failure if conforms_to(Self.M, ApplicativeError) else Self._Mapping.Failure
    comptime _ErrorCarrier[V: Movable & Deinitable] = Self.CarrierCompatible[V] and Self._Errors._ErrorCarrier[_Action[V].Out]
    comptime ErrorCarrierCompatible[V: Movable & Deinitable] = Self._Mapping.ErrorCarrierCompatible[_Action[V].Out] if Self.CarrierCompatible[V] else False
    # A base may map into a non-Monad. Retain that real candidate for normal
    # target rejection; only an actual Monad can be wrapped in this layer.
    comptime _DefaultErrorBase[A: Movable & Deinitable, E: Movable & Deinitable] = Self._Mapping.DefaultErrorTarget[Tuple[A, Self.S],E]
    comptime DefaultErrorTarget[A: Movable & Deinitable, E: Movable & Deinitable] = StateT[downcast[Self._DefaultErrorBase[A,E],Monad],Self.S] if conforms_to(Self._DefaultErrorBase[A,E],Monad) else Self._DefaultErrorBase[A,E]
    comptime _BimapTarget[Target: ErrorMapping] = (Target == StateT[downcast[Target, StateFamily].Base,Self.S] and conforms_to(downcast[Target, StateFamily].Base,ErrorMapping)) if conforms_to(Target,StateFamily) else False
    comptime _MappingOperation[Target: ErrorMapping, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = _BimapOp[Self._Mapping,downcast[downcast[Target, StateFamily].Base,ErrorMapping],_MapFirst[F, Self.S],G]
    comptime BimapCompatible[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Self._HoistCompatible[V,Self._MappingOperation[Target,F,G]] if Self._BimapTarget[Target] else False
    comptime Bimapped[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Self._HoistedAs[F.Out,V,Self._MappingOperation[Target,F,G],downcast[Target,StateFamily]]
    comptime BimapError[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Self._HoistError[F.Out,V,Self._MappingOperation[Target,F,G]]

    @staticmethod
    def bimap[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](var on_ok: F, var on_err: G, var source: V) raises Self.BimapError[Target,V,F,G] -> Self.Bimapped[Target,V,F,G]:
        """Defer one selected base-outcome transformation, retaining owned state.

        Parameters:
            Target: The admitted destination with the same environment, state or log.
            V: The source carrier type, including origins.
            F: The consuming success callback type.
            G: The consuming stored-error callback type.

        Args:
            on_ok: The callback selected by an original success.
            on_err: The callback selected by an original stored error.
            source: The source carrier, consumed once.

        Returns:
            A destination State action; construction neither runs nor copies state.

        Raises:
            Nothing at construction; running preserves the source and base errors.
        """
        comptime assert Self.BimapCompatible[Target,V,F,G]
        return Self._hoist_as[F.Out,V,Self._MappingOperation[Target,F,G],downcast[Target,StateFamily]](Self._MappingOperation[Target,F,G](_MapFirst[F, Self.S](on_ok^),on_err^),source^)

    comptime Failed[A: Movable & Deinitable] = _StateFail[Self.M, Self.S, A]
    comptime FailError[A: Movable & Deinitable] = Never
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = _StateBind[Self.M, Self.S, _Action[V], H, True]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Never

    @staticmethod
    def fail[A: Movable & Deinitable](var error: Self.Failure) -> Self.Failed[A]:
        """Defer construction of a base failure; no state payload survives it.

        Parameters:
            A: The absent success payload type.

        Args:
            error: The selected base error, consumed with its exact origins.

        Returns:
            A deferred computation; base failure construction runs only at run.
        """
        # Normalize the capability-conditional alias without changing origins.
        comptime assert Self.Failure == Self._Errors.Failure
        return Self.Failed[A](rebind_var[Self._Errors.Failure](error^))

    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) -> Self.Handled[V, H]:
        """Run recovery on the saved input state at this boundary.

        Parameters:
            V: The State computation of this family.
            H: The handler consuming the selected stored error and returning
                this family with the same success type; repeatable for branching.

        Args:
            handler: The handler, consumed and skipped on success.
            source: The source, consumed with its native origins.

        Returns:
            A deferred State computation that saves its input and runs the source
            on a copy. Recovery uses the saved state; repeated branches copy it.
            This capability requires Copyable state.
        """
        comptime assert conforms_to(Self.S, Copyable), "StateT recovery requires Copyable input state"
        comptime assert Self._Handles[V, H], "or_else: State family or payload mismatch"
        return Self.Handled[V, H](rebind_var[_Action[V]](source^), handler^)

    comptime Base = Self.M
    comptime StateType = Self.S
    comptime EndpointCompatible[T: Movable & Deinitable, F: Movable & Deinitable] = (
        downcast[F, UnaryContract].Arg == Self.S and
        _EndpointCompatible[Self.M, Tuple[T, Self.S], downcast[F, UnaryContract].Out]
    ) if conforms_to(F, UnaryContract) else False
    comptime Element[V: Movable & Deinitable] = _Action[V].Value
    comptime CarrierCompatible[V: Movable & Deinitable] = (_Action[V].Family == Self and _Action[V].State == Self.S and Self.M.CarrierCompatible[_Action[V].Out] and Self.M.Element[_Action[V].Out] == Tuple[Self.Element[V], Self.S]) if conforms_to(V, StateAction) else False
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.CarrierCompatible[V]
    comptime BindCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _CarrierBind[Self, V, F]
    comptime CombineCompatible[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = _CarrierCombine[Self, V, F, G]
    comptime CollectCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.CarrierCompatible[F.Out]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _StateMap[Self.M, Self.S, _Action[V], F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Never
    comptime Pure[A: Movable & Deinitable] = _StatePure[Self.M, Self.S, A]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = _StateCombine[Self.M, Self.S, _Action[V], F, G]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = Never
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _StateBind[Self.M, Self.S, _Action[V], F]
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Never
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _StateLoop[Self.M, Self.S, V, F, K]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Never
    comptime _Folded[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator] = _StateFold[Self.M, Self.S, V, P, F, K]
    comptime _FoldError[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator] = Never
    @staticmethod
    def _fold[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator](var prepare: P, var step: F, var initial: K.Acc, var source: V) -> Self._Folded[V, P, F, K]:
        return Self._Folded[V, P, F, K](prepare^, step^, initial^, source^)
    comptime _JoinCompatible[L: Movable & Deinitable, R: Movable & Deinitable] = Self.CarrierCompatible[L] and Self.CarrierCompatible[R] and Self.Element[L] == Self.Element[R]
    comptime _Joined[L: Movable & Deinitable, R: Movable & Deinitable] = _StateChoice[Self.M, _Action[L], _Action[R]]
    comptime Lifted[V: Movable & Deinitable] = _StateLift[Self.M, Self.S, V]
    comptime Endpoint[T: Movable & Deinitable, F: Movable & Deinitable] = _StateEndpoint[
        Self.M, Self.S, T, downcast[F, UnaryContract & Movable & Deinitable]]
    comptime LiftError[V: Movable & Deinitable] = Never

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) -> Self.Mapped[V, F]:
        """A State computation that maps the payload of `value` with `f` when run; the state passes through.

        Parameters:
            V: The computation's type.
            F: The callback's type.

        Args:
            f: The callback, consumed.
            value: The computation, consumed.

        Returns:
            The mapping computation; nothing runs now.
        """
        comptime assert Self.MapCompatible[V, F], _FAMILY_MISMATCH
        return Self.Mapped[V, F](rebind_var[_Action[V]](value^), f^)

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        """A State computation that returns `value` and the state unchanged.

        Parameters:
            A: The payload type.

        Args:
            value: The payload, consumed.

        Returns:
            The computation.
        """
        return Self.Pure[A](value^)

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: G
    ) -> Self.Combined[V, F, G]:
        """A State computation that runs the left operand, then the right one on the state the left produced, and combines their payloads.

        Parameters:
            V: The left computation's type.
            F: The combiner's type.
            G: The right operand's type: a thunk producing a computation of this family.

        Args:
            f: The combiner, consumed.
            left: The left computation, consumed.
            right: The thunk producing the right computation, consumed.

        Returns:
            The combining computation; nothing runs now.
        """
        comptime assert Self.CombineCompatible[V, F, G], _FAMILY_MISMATCH
        return Self.Combined[V, F, G](rebind_var[_Action[V]](left^), f^, right^)

    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) -> Self.Bound[V, F]:
        """A State computation that runs `value`, then the computation `f` returns on the updated state.

        Parameters:
            V: The computation's type.
            F: The callback's type, returning a computation of this family.

        Args:
            f: The callback, consumed.
            value: The computation, consumed.

        Returns:
            The bound computation; nothing runs now.
        """
        comptime assert Self.BindCompatible[V, F], _FAMILY_MISMATCH
        return Self.Bound[V, F](rebind_var[_Action[V]](value^), f^)

    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V
    ) -> Self._Looped[V, F, K]:
        return Self._Looped[V, F, K](source^, f^)

    @staticmethod
    def _join_left[L: Movable & Deinitable, R: Movable & Deinitable](var value: L) -> Self._Joined[L, R]:
        comptime assert _Action[L].Family == Self and _Action[R].Family == Self, _CHOICE_FAMILY
        return Self._Joined[L, R](Variant[_Action[L], _Action[R]](rebind_var[_Action[L]](value^)))

    @staticmethod
    def _join_right[L: Movable & Deinitable, R: Movable & Deinitable](var value: R) -> Self._Joined[L, R]:
        comptime assert _Action[L].Family == Self and _Action[R].Family == Self, _CHOICE_FAMILY
        return Self._Joined[L, R](Variant[_Action[L], _Action[R]](rebind_var[_Action[R]](value^)))

    @staticmethod
    def lift[V: Movable & Deinitable](var value: V) -> Self.Lifted[V]:
        """A State computation that returns a base carrier's payload with the state unchanged.

        Parameters:
            V: The base carrier's type.

        Args:
            value: The base carrier, consumed.

        Returns:
            The computation.
        """
        return Self.Lifted[V](value^)

    @staticmethod
    def endpoint[T: Movable & Deinitable, F: Movable & Deinitable](var f: F) -> Self.Endpoint[T, F]:
        """A State computation from a callback that consumes the state; `action[I, T](f)` calls this.

        Parameters:
            T: The payload type.
            F: The callback's type.

        Args:
            f: The callback, consumed.

        Returns:
            The computation.
        """
        comptime assert conforms_to(F, UnaryContract), "action: a State endpoint must be a unary callback consuming the state"
        comptime D = downcast[F, UnaryContract & Movable & Deinitable]
        comptime assert Self.EndpointCompatible[T, F], "action: native result differs from declared carrier"
        return Self.Endpoint[T, F](rebind_var[D](f^))


comptime State[S: Movable & Deinitable] = StateT[IdentityFamily, S]
"""State over the bare value: a computation consumes an `S` and returns `(value, state)`.

Parameters:
    S: The state's type.
"""


# Preserve the original module import path; capabilities owns the public API.
from .capabilities import get, modify, put
