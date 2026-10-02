"""State: deferred computations threading an owned state through any base Monad.

A run consumes the state and returns the base carrier of Tuple[value, state].
Each operation is one struct whose run delegates to the base family.
"""
from std.builtin.rebind import rebind_var, rebind, downcast
from std.utils import Variant
from fp.algebra.protocols import (Monad, _Lifting, _Accumulate, _BindFirst, _Lazy, _Item, _iterator, _next_item, _start_as)
from fp.algebra.instances import IdentityFamily
from fp.callables.protocols import (UnaryContract, BinaryContract, ThunkContract, Unary, OnceUnary, MutableUnary)
from fp.callables.invoke import call_once, call_repeated, RepeatableUnary
from fp.callables.native import NativeUnary, as_unary, _Unary, _RaisingUnary
from std.memory import MaybeUninit
from fp.callables.products import _take_pair
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from .protocols import StateAction, _StateFamily, _admit_endpoint, _FAMILY_MISMATCH, _CHOICE_FAMILY, _CHOICE_VALUE
from ._adapt import _state_run_as, _map_as, _flat_map_as


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
struct _Replace[S: Movable & Deinitable](OnceUnary, Copyable where conforms_to(S, Copyable)):
    var value: Self.S
    comptime Arg = Self.S
    comptime Out = Self.S
    def call_once(deinit self, var arg: Self.Arg) -> Self.Out:
        return self.value^


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
struct _WithState[A: Movable & Deinitable, S: Movable & Deinitable](OnceUnary, MutableUnary where conforms_to(S, Copyable)):
    """Pair each base payload with the state; repeated pairing copies it."""
    var state: Self.S
    comptime Arg = Self.A
    comptime Out = Tuple[Self.A, Self.S]
    def call_once(deinit self, var arg: Self.Arg) -> Self.Out:
        return Tuple(arg^, self.state^)
    def call_mut(mut self, var arg: Self.Arg) -> Self.Out:
        comptime C = downcast[Self.S, Copyable & Deinitable]
        return Tuple(arg^, rebind_var[Self.S](rebind[C](self.state).copy()))


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
struct _StateContinue[I: AnyType, F: UnaryContract & Movable & Deinitable, S: Movable & Deinitable](
    OnceUnary, MutableUnary where RepeatableUnary[F], Copyable where conforms_to(F, Copyable)
):
    """Call F with the value, then run its computation on the paired state."""
    var function: Self.F
    comptime Action = _Action[Self.F.Out]
    comptime Arg = Tuple[Self.F.Arg, Self.S]
    comptime Out = Self.Action.Out
    comptime Error = _CommonError[Self.F.Error, Self.Action.Error]
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert Self.Action.Family == Self.I, _FAMILY_MISMATCH
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error] and _ErrorCompatible[Self.Error, Self.Action.Error]
        var value_slot = MaybeUninit[Self.F.Arg]()
        var state_slot = MaybeUninit[Self.S]()
        _take_pair(arg^, value_slot, state_slot)
        var value_part = value_slot^.unsafe_assume_init()
        var state_part = state_slot^.unsafe_assume_init()
        var action: Self.Action
        try:
            action = rebind_var[Self.Action](call_once(self.function^, value_part^))
        except error:
            _propagate_error[Self.Error](error^)
        return _state_run_as[Self.Error](action^, rebind_var[Self.Action.State](state_part^))
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert Self.Action.Family == Self.I, _FAMILY_MISMATCH
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error] and _ErrorCompatible[Self.Error, Self.Action.Error]
        comptime assert RepeatableUnary[Self.F]
        var value_slot = MaybeUninit[Self.F.Arg]()
        var state_slot = MaybeUninit[Self.S]()
        _take_pair(arg^, value_slot, state_slot)
        var value_part = value_slot^.unsafe_assume_init()
        var state_part = state_slot^.unsafe_assume_init()
        var action: Self.Action
        try:
            action = rebind_var[Self.Action](call_repeated(self.function, value_part^))
        except error:
            _propagate_error[Self.Error](error^)
        return _state_run_as[Self.Error](action^, rebind_var[Self.Action.State](state_part^))


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
        var action: Self.Action
        try:
            action = rebind_var[Self.Action](self.right^.take())
        except error:
            _propagate_error[Self.Error](error^)
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
struct _StateBind[M: Monad, S: Movable & Deinitable, A: StateAction, F: UnaryContract & Movable & Deinitable](
    StateAction, Copyable where conforms_to(A, Copyable) and conforms_to(F, Copyable)
):
    var source: Self.A
    var function: Self.F
    comptime Family = StateT[Self.M, Self.S]
    comptime State = Self.S
    comptime Value = _Action[Self.F.Out].Value
    comptime Next = _StateContinue[Self.Family, Self.F, Self.S]
    comptime Out = Self.M.Bound[Self.A.Out, Self.Next]
    comptime Error = _CommonError[Self.A.Error, Self.M.BindError[Self.A.Out, Self.Next]]
    def run(deinit self, var state: Self.State) raises Self.Error -> Self.Out:
        comptime assert _Action[Self.F.Out].Family == Self.Family, _FAMILY_MISMATCH
        comptime assert _ErrorCompatible[Self.Error, Self.A.Error] and _ErrorCompatible[Self.Error, Self.M.BindError[Self.A.Out, Self.Next]]
        var base = _state_run_as[Self.Error](self.source^, rebind_var[Self.A.State](state^))
        return _flat_map_as[Self.Error, Self.M](Self.Next(self.function^), base^)


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


@fieldwise_init
struct _Live[K: _Accumulate, S: Movable & Deinitable, o: MutOrigin](Unary):
    """Identity on a branch's (accumulator, state) that records whether the
    base carrier has a live branch."""
    var live: Pointer[Bool, Self.o]
    comptime Arg = Tuple[Self.K.Acc, Self.S]
    comptime Out = Tuple[Self.K.Acc, Self.S]
    def call(self, var arg: Self.Arg) -> Self.Out:
        if Self.K.live(arg[0]):
            self.live[] = True
        return arg^


@fieldwise_init
struct _LiveShape[K: _Accumulate, S: Movable & Deinitable](UnaryContract):
    # The type and error of `_Live`, without its scoped pointer.
    comptime Arg = Tuple[Self.K.Acc, Self.S]
    comptime Out = Tuple[Self.K.Acc, Self.S]


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
struct _StateStep[I: AnyType, M: Monad, S: Movable & Deinitable, K: _Accumulate, A: StateAction](
    OnceUnary, MutableUnary where conforms_to(A, Copyable) and conforms_to(K.Acc, Copyable)
):
    """Run one prepared computation on a live branch's state and fold its value;
    an inactive branch carries unchanged. Every live branch receives the same
    prepared computation."""
    var action: Self.A
    comptime Arg = Tuple[Self.K.Acc, Self.S]
    comptime Fold = _FoldState[Self.K, Self.S]
    comptime Out = Self.M.Mapped[Self.A.Out, Self.Fold]
    comptime Error = _CommonError[Self.A.Error, Self.M.MapError[Self.A.Out, Self.Fold]]
    @staticmethod
    def _step(var action: Self.A, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert Self.A.Family == Self.I, _FAMILY_MISMATCH
        comptime assert Self.A.Value == Self.K.Item, "traverse: every produced computation must have the accumulated value type"
        comptime assert Self.M.Pure[Self.Arg] == Self.Out, "traverse: State traversal needs a base whose carrier type stays the same across steps"
        comptime assert _ErrorCompatible[Self.Error, Self.A.Error] and _ErrorCompatible[Self.Error, Self.M.MapError[Self.A.Out, Self.Fold]]
        if not Self.K.live(arg[0]):
            return rebind_var[Self.Out](Self.M.pure(arg^))
        var value_slot = MaybeUninit[Self.K.Acc]()
        var state_slot = MaybeUninit[Self.S]()
        _take_pair(arg^, value_slot, state_slot)
        var value_part = value_slot^.unsafe_assume_init()
        var state_part = state_slot^.unsafe_assume_init()
        var based = _state_run_as[Self.Error](action^, rebind_var[Self.A.State](state_part^))
        return _map_as[Self.Error, Self.M](Self.Fold(value_part^), based^)
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        return Self._step(self.action^, arg^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime C = downcast[Self.A, Copyable & Deinitable]
        return Self._step(rebind_var[Self.A](rebind[C](self.action).copy()), arg^)


@fieldwise_init
struct _StateLoop[M: Monad, S: Movable & Deinitable, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable,
                  K: _Accumulate](
    StateAction, Copyable where conforms_to(V, Copyable) and conforms_to(F, Copyable)
):
    """One deferred traversal. When run, each step first checks that the base
    carrier has a live branch, then pulls one item, prepares its computation
    once, and binds it across the branches: live branches run it on their own
    state and fold its value, inactive branches carry."""
    var source: Self.V
    var function: Self.F
    comptime Family = StateT[Self.M, Self.S]
    comptime State = Self.S
    comptime Produced = _Action[Self.F.Out]
    comptime Value = Self.K.Acc
    comptime Pair = Tuple[Self.K.Acc, Self.S]
    comptime Acc = Self.M.Pure[Self.Pair]
    comptime Step = _StateStep[Self.Family, Self.M, Self.S, Self.K, Self.Produced]
    comptime Out = Self.Acc
    comptime Error = _CommonError[Self.K.Error, _CommonError[Self.F.Error, _CommonError[
        Self.M.MapError[Self.Acc, _LiveShape[Self.K, Self.S]], Self.M.BindError[Self.Acc, Self.Step]]]]
    def run(deinit self, var state: Self.State) raises Self.Error -> Self.Out:
        comptime E = Self.Error
        comptime assert RepeatableUnary[Self.F], "traverse: the callback must be repeatable"
        comptime assert Self.Produced.Family == Self.Family, _FAMILY_MISMATCH
        comptime assert _Item[Self.V] == Self.F.Arg, "traverse: callback argument must be the source element"
        comptime assert Self.M.Bound[Self.Acc, Self.Step] == Self.Acc and Self.M.Mapped[Self.Acc, _LiveShape[Self.K, Self.S]] == Self.Acc, "traverse: State traversal needs a base whose carrier type stays the same across steps"
        comptime assert _ErrorCompatible[E, Self.K.Error] and _ErrorCompatible[E, Self.F.Error] and _ErrorCompatible[E, Self.M.BindError[Self.Acc, Self.Step]]
        var iterator = _iterator(self.source^)
        var function = self.function^
        var result = Self.M.pure(Tuple(_start_as[E, Self.K](), state^))
        while True:
            var live = False
            comptime Probe = _Live[Self.K, Self.S, origin_of(live)]
            comptime assert Self.M.MapError[Self.Acc, Probe] == Self.M.MapError[Self.Acc, _LiveShape[Self.K, Self.S]]
            comptime assert _ErrorCompatible[E, Self.M.MapError[Self.Acc, Probe]]
            result = rebind_var[Self.Acc](_map_as[E, Self.M](Probe(Pointer(to=live)), result^))
            if not live:
                return result^
            var item = _next_item[Self.V](iterator)
            if not item:
                return result^
            var produced: Self.Produced
            try:
                produced = rebind_var[Self.Produced](call_repeated(function, rebind_var[Self.F.Arg](item.unsafe_take())))
            except error:
                _propagate_error[E](error^)
            result = rebind_var[Self.Acc](_flat_map_as[E, Self.M](Self.Step(produced^), result^))


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


struct StateT[M: Monad, S: Movable & Deinitable](_StateFamily, _Lifting):
    """State over the base Monad `M`: a computation consumes a state `S` when run and returns an `M` carrier of `(value, state)`.

    Computations are built as for `ReaderT` and run with `run`. Traversal is one
    loop: it checks that the base carrier still has a live branch, pulls one
    item, calls the producer once, and binds the prepared computation across
    the live branches, each on its own state. A failed, absent or empty carrier
    stops producer calls and source pulls. The base carrier's type must stay
    the same across steps, as it does for Identity, Optional, Result and List;
    a deferred base is a compile error there.

    Parameters:
        M: The base Monad.
        S: The state's type.
    """
    comptime Base = Self.M
    comptime StateType = Self.S
    comptime Element[V: Movable & Deinitable] = _Action[V].Value
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _StateMap[Self.M, Self.S, _Action[V], F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Never
    comptime Pure[A: Movable & Deinitable] = _StatePure[Self.M, Self.S, A]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = _StateCombine[Self.M, Self.S, _Action[V], F, G]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = Never
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _StateBind[Self.M, Self.S, _Action[V], F]
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Never
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _StateLoop[Self.M, Self.S, V, F, K]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Never
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
        comptime assert _Action[V].Family == Self, _FAMILY_MISMATCH
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
        comptime assert _Action[V].Family == Self, _FAMILY_MISMATCH
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
        comptime assert _Action[V].Family == Self, _FAMILY_MISMATCH
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
        _admit_endpoint[Self.M, Tuple[T, Self.S], D.Out]()
        return Self.Endpoint[T, F](rebind_var[D](f^))


comptime State[S: Movable & Deinitable] = StateT[IdentityFamily, S]
"""State over the bare value: a computation consumes an `S` and returns `(value, state)`.

Parameters:
    S: The state's type.
"""


def get[I: _StateFamily]() -> _StateGet[I.Base, downcast[I.StateType, Copyable & Deinitable]] where conforms_to(I.StateType, Copyable):
    """A State computation whose payload is a copy of the state, which is kept.

    Parameters:
        I: The State family; its state must be `Copyable`.

    Returns:
        The computation.
    """
    return _StateGet[I.Base, downcast[I.StateType, Copyable & Deinitable]]()


def modify[F: UnaryContract & Movable & Deinitable, //, I: _StateFamily](var f: F) -> _StateModify[I.Base, I.StateType, F]:
    """A State computation that replaces the state with `f(state)`; its payload is `None`.

    Other overloads take a native function or closure directly.

    Parameters:
        F: The callback's type: a library `Unary` value from state to state.
        I: The State family.

    Args:
        f: The callback, consumed.

    Returns:
        The computation.
    """
    return _StateModify[I.Base, I.StateType, F](f^)


def modify[A: Movable & Deinitable, R: Movable & Deinitable, //, I: _StateFamily, F: _Unary[A, R]](
    var f: F
) -> _StateModify[I.Base, I.StateType, NativeUnary[A, R, Never, F, False]] where A == I.StateType and R == I.StateType:
    """Replace the state with f(state), for a native function or closure."""
    return modify[I](as_unary(f^))


def modify[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, I: _StateFamily, F: _RaisingUnary[A, R, E]](
    var f: F
) -> _StateModify[I.Base, I.StateType, NativeUnary[A, R, E, F, True]] where A == I.StateType and R == I.StateType:
    """Raising form of the native modify; its error type is kept."""
    return modify[I](as_unary(f^))


def put[I: _StateFamily](var state: I.StateType) -> _StateModify[I.Base, I.StateType, _Replace[I.StateType]]:
    """A State computation that replaces the state; the previous state is destroyed.

    Parameters:
        I: The State family.

    Args:
        state: The new state, consumed.

    Returns:
        The computation.
    """
    return modify[I](_Replace[I.StateType](state^))
