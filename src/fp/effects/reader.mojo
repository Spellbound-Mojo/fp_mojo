"""Reader: deferred computations over a borrowed environment and any base Monad.

Each operation is one struct whose run delegates to the base family. A result
that retains the environment, such as a bind over a deferred base, carries the
environment origin in its type.
"""
from std.builtin.rebind import rebind_var, downcast
from std.utils import Variant
from fp.algebra.errors import _Continue
from fp.algebra.protocols import ApplicativeError, Monad, _Accumulate, _LiveAccumulator
from fp.algebra.instances import IdentityFamily
from fp.callables.protocols import (UnaryContract, BinaryContract, ThunkContract, OnceUnary, MutableUnary,
                                    OnceThunk, MutableBinary, BorrowCallContract, BorrowCallable, BorrowOnceCallable)
from fp.callables.invoke import call_once, call_repeated, RepeatableUnary, RepeatableBinary
from fp.callables._receiver import _borrow_once_as, _binary_repeated_as
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from .protocols import Local, Listen, _CarrierOp, _LocalLifting, ReaderAction, _ReaderFamily, _admit_endpoint, _FAMILY_MISMATCH, _CHOICE_FAMILY, _CHOICE_VALUE
from ._adapt import _op_as, _reader_run_as, _map_as, _flat_map_as, _map2_lazy_as

from ._transport import _LocalOp, _ListenOp, _ListenMapped, _ListenPair


comptime _Action[V: Movable & Deinitable] = downcast[V, ReaderAction]

# Empty and universal native origin witnesses are used only in admission
# predicates, never to run an action or relabel a borrow. The universal witness
# also detects unions with fixed origins (two finite witnesses can collapse
# to the same union). If Out or Error retains the run environment, substitution
# changes its type. Keep this check in a public
# where clause: body-level equality assertions erase origin distinctions on
# Mojo 1.1 and cannot protect the temporary local environment.
comptime _LocalIndependent[V: ReaderAction] = V.Out[ImmUntrackedOrigin] == V.Out[ImmutAnyOrigin] and V.Error[ImmUntrackedOrigin] == V.Error[ImmutAnyOrigin]


@fieldwise_init
struct _ReaderPure[M: Monad, R: AnyType, T: Movable & Deinitable](ReaderAction, Copyable where conforms_to(T, Copyable)):
    var value: Self.T
    comptime Family = ReaderT[Self.M, Self.R]
    comptime Env = Self.R
    comptime Value = Self.T
    comptime Out[o: ImmOrigin] = Self.M.Pure[Self.T]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        return Self.M.pure(self.value^)


@fieldwise_init
struct _ReaderFail[M: Monad, R: AnyType, A: Movable & Deinitable](ReaderAction, Copyable where conforms_to(downcast[M, ApplicativeError].Failure, Copyable)):
    """Borrowed-environment boundary for a deferred base failure."""
    comptime Errors = downcast[Self.M, ApplicativeError]
    var error: Self.Errors.Failure
    comptime Family = ReaderT[Self.M, Self.R]
    comptime Env = Self.R
    comptime Value = Self.A
    comptime Out[o: ImmOrigin] = Self.Errors.Failed[Self.A]
    comptime Error[o: ImmOrigin] = Self.Errors.FailError[Self.A]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) raises Self.Error[o] -> Self.Out[o]:
        return Self.Errors.fail[Self.A](self.error^)


@fieldwise_init
struct _ReaderLift[M: Monad, R: AnyType, V: Movable & Deinitable](ReaderAction, Copyable where conforms_to(V, Copyable)):
    """A base carrier that ignores the environment."""
    var value: Self.V
    comptime Family = ReaderT[Self.M, Self.R]
    comptime Env = Self.R
    comptime Value = Self.M.Element[Self.V]
    comptime Out[o: ImmOrigin] = Self.V
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        return self.value^


@fieldwise_init
struct _ReaderAsk[M: Monad, R: Copyable & Deinitable](ReaderAction, Copyable, Defaultable):
    comptime Family = ReaderT[Self.M, Self.R]
    comptime Env = Self.R
    comptime Value = Self.R
    comptime Out[o: ImmOrigin] = Self.M.Pure[Self.R]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        return Self.M.pure(env.copy())


@fieldwise_init
struct _ReaderEndpoint[M: Monad, R: AnyType, T: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable](
    ReaderAction, Copyable where conforms_to(F, Copyable)
):
    """A native endpoint borrowing the environment and returning a base carrier."""
    var function: Self.F
    comptime Family = ReaderT[Self.M, Self.R]
    comptime Env = Self.R
    comptime Value = Self.T
    comptime Out[o: ImmOrigin] = Self.F.Result
    comptime Error[o: ImmOrigin] = Self.F.Failure
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) raises Self.Error[o] -> Self.Out[o]:
        comptime assert Self.F.Payload == Self.R, "action: the endpoint must borrow the Reader environment"
        return _borrow_once_as[Self.Error[o]](env, self.function^)


@fieldwise_init
struct _ReaderContinue[I: AnyType, F: UnaryContract & Movable & Deinitable, R: AnyType, o: ImmOrigin](
    OnceUnary, MutableUnary where RepeatableUnary[F], Copyable where conforms_to(F, Copyable)
):
    """Call F, then run its computation in the same borrowed environment."""
    var function: Self.F
    var env: Pointer[Self.R, Self.o]
    comptime Action = _Action[Self.F.Out]
    comptime Arg = Self.F.Arg
    comptime Out = Self.Action.Out[Self.o]
    comptime Error = _CommonError[Self.F.Error, Self.Action.Error[Self.o]]
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert Self.Action.Family == Self.I, _FAMILY_MISMATCH
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error] and _ErrorCompatible[Self.Error, Self.Action.Error[Self.o]]
        var action: Self.Action
        try:
            action = rebind_var[Self.Action](call_once(self.function^, arg^))
        except error:
            _propagate_error[Self.Error](error^)
        return _reader_run_as[Self.Error](action^, rebind[Self.Action.Env](self.env[]))
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert Self.Action.Family == Self.I, _FAMILY_MISMATCH
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error] and _ErrorCompatible[Self.Error, Self.Action.Error[Self.o]]
        comptime assert RepeatableUnary[Self.F]
        var action: Self.Action
        try:
            action = rebind_var[Self.Action](call_repeated(self.function, arg^))
        except error:
            _propagate_error[Self.Error](error^)
        return _reader_run_as[Self.Error](action^, rebind[Self.Action.Env](self.env[]))


@fieldwise_init
struct _ReaderRight[I: AnyType, G: ThunkContract & Movable & Deinitable, R: AnyType, o: ImmOrigin](OnceThunk):
    """Produce the right computation, then run it in the borrowed environment."""
    var right: Self.G
    var env: Pointer[Self.R, Self.o]
    comptime Action = _Action[Self.G.Out]
    comptime Out = Self.Action.Out[Self.o]
    comptime Error = _CommonError[Self.G.Error, Self.Action.Error[Self.o]]
    def call_once(deinit self) raises Self.Error -> Self.Out:
        comptime assert Self.Action.Family == Self.I, _FAMILY_MISMATCH
        comptime assert _ErrorCompatible[Self.Error, Self.G.Error] and _ErrorCompatible[Self.Error, Self.Action.Error[Self.o]]
        var action: Self.Action
        try:
            action = rebind_var[Self.Action](call_once(self.right^))
        except error:
            _propagate_error[Self.Error](error^)
        return _reader_run_as[Self.Error](action^, rebind[Self.Action.Env](self.env[]))


@fieldwise_init
struct _ReaderMap[M: Monad, R: AnyType, S: ReaderAction, F: UnaryContract & Movable & Deinitable](
    ReaderAction, Copyable where conforms_to(S, Copyable) and conforms_to(F, Copyable)
):
    var source: Self.S
    var function: Self.F
    comptime Family = ReaderT[Self.M, Self.R]
    comptime Env = Self.R
    comptime Value = Self.F.Out
    comptime Out[o: ImmOrigin] = Self.M.Mapped[Self.S.Out[o], Self.F]
    comptime Error[o: ImmOrigin] = _CommonError[Self.S.Error[o], Self.M.MapError[Self.S.Out[o], Self.F]]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) raises Self.Error[o] -> Self.Out[o]:
        comptime E = Self.Error[o]
        comptime assert _ErrorCompatible[E, Self.S.Error[o]] and _ErrorCompatible[E, Self.M.MapError[Self.S.Out[o], Self.F]]
        var base = _reader_run_as[E](self.source^, rebind[Self.S.Env](env))
        return _map_as[E, Self.M](self.function^, base^)


@fieldwise_init
struct _ReaderBind[M: Monad, R: AnyType, S: ReaderAction, F: UnaryContract & Movable & Deinitable, recover: Bool = False](
    ReaderAction, Copyable where conforms_to(S, Copyable) and conforms_to(F, Copyable)
):
    var source: Self.S
    var function: Self.F
    comptime Family = ReaderT[Self.M, Self.R]
    comptime Env = Self.R
    comptime Value = _Action[Self.F.Out].Value
    comptime Operation = _Continue[Self.M, Self.recover]
    comptime Next[o: ImmOrigin] = _ReaderContinue[Self.Family, Self.F, Self.R, o]
    comptime Out[o: ImmOrigin] = Self.Operation.Out[Self.S.Out[o], Self.Next[o]]
    comptime Error[o: ImmOrigin] = _CommonError[Self.S.Error[o], Self.Operation.Error[Self.S.Out[o], Self.Next[o]]]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) raises Self.Error[o] -> Self.Out[o]:
        comptime E = Self.Error[o]
        comptime assert _Action[Self.F.Out].Family == Self.Family, _FAMILY_MISMATCH
        comptime assert _ErrorCompatible[E, Self.S.Error[o]] and _ErrorCompatible[E, Self.Operation.Error[Self.S.Out[o], Self.Next[o]]]
        var base = _reader_run_as[E](self.source^, rebind[Self.S.Env](env))
        return Self.Operation.apply[E](Self.Next[o](self.function^, Pointer(to=env)), base^)


@fieldwise_init
struct _ReaderCombine[M: Monad, R: AnyType, S: ReaderAction, F: BinaryContract & Movable & Deinitable,
                      G: ThunkContract & Movable & Deinitable](
    ReaderAction, Copyable where conforms_to(S, Copyable) and conforms_to(F, Copyable) and conforms_to(G, Copyable)
):
    """Both operands read the same environment; the base combines their carriers."""
    var source: Self.S
    var function: Self.F
    var right: Self.G
    comptime Family = ReaderT[Self.M, Self.R]
    comptime Env = Self.R
    comptime Value = Self.F.Out
    comptime Right[o: ImmOrigin] = _ReaderRight[Self.Family, Self.G, Self.R, o]
    comptime Out[o: ImmOrigin] = Self.M.Combined[Self.S.Out[o], Self.F, Self.Right[o]]
    comptime Error[o: ImmOrigin] = _CommonError[Self.S.Error[o], Self.M.CombineError[Self.S.Out[o], Self.F, Self.Right[o]]]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) raises Self.Error[o] -> Self.Out[o]:
        comptime E = Self.Error[o]
        comptime assert _Action[Self.G.Out].Family == Self.Family, _FAMILY_MISMATCH
        comptime assert _ErrorCompatible[E, Self.S.Error[o]] and _ErrorCompatible[E, Self.M.CombineError[Self.S.Out[o], Self.F, Self.Right[o]]]
        var base = _reader_run_as[E](self.source^, rebind[Self.S.Env](env))
        return _map2_lazy_as[E, Self.M](self.function^, base^, Self.Right[o](self.right^, Pointer(to=env)))


@fieldwise_init
struct _ReaderLocal[M: Monad, R: Movable & Deinitable, S: ReaderAction, F: BorrowCallContract & Movable & Deinitable](
    ReaderAction, Copyable where conforms_to(S, Copyable) and conforms_to(F, Copyable)
):
    """Run S with an environment computed from the current one."""
    var source: Self.S
    var function: Self.F
    comptime Family = ReaderT[Self.M, Self.R]
    comptime Env = Self.R
    comptime Value = Self.S.Value
    comptime Out[o: ImmOrigin] = Self.S.Out[o]
    comptime Error[o: ImmOrigin] = _CommonError[Self.F.Failure, Self.S.Error[o]]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) raises Self.Error[o] -> Self.Out[o]:
        comptime E = Self.Error[o]
        comptime assert Self.F.Payload == Self.R and Self.F.Result == Self.R, "local: the callback must map the environment to a new environment"
        comptime assert _ErrorCompatible[E, Self.F.Failure] and _ErrorCompatible[E, Self.S.Error[o]]
        var changed = rebind_var[Self.R](_borrow_once_as[E](env, self.function^))
        # The changed environment lives only for this run, so the result must
        # not retain it: the base must complete the computation eagerly.
        comptime assert Self.S.Out[origin_of(changed)] == Self.S.Out[o], "local: the base retains the environment; run local over an eager base"
        comptime assert _ErrorCompatible[E, Self.S.Error[origin_of(changed)]]
        return rebind_var[Self.Out[o]](_reader_run_as[E](self.source^, rebind[Self.S.Env](changed)))


@fieldwise_init
struct _ReaderLoop[M: Monad, R: AnyType, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](
    ReaderAction, Copyable where conforms_to(V, Copyable) and conforms_to(F, Copyable)
):
    """One deferred traversal: when run, the base loops over the source, and
    each produced computation runs on the borrowed environment."""
    var source: Self.V
    var function: Self.F
    comptime Family = ReaderT[Self.M, Self.R]
    comptime Env = Self.R
    comptime Value = Self.K.Acc
    comptime Step[o: ImmOrigin] = _ReaderContinue[Self.Family, Self.F, Self.R, o]
    comptime Out[o: ImmOrigin] = Self.M._Looped[Self.V, Self.Step[o], Self.K]
    comptime Error[o: ImmOrigin] = Self.M._LoopError[Self.V, Self.Step[o], Self.K]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) raises Self.Error[o] -> Self.Out[o]:
        comptime assert RepeatableUnary[Self.F], "traverse: the callback must be repeatable"
        comptime assert _Action[Self.F.Out].Family == Self.Family, _FAMILY_MISMATCH
        return Self.M._loop[Self.V, Self.Step[o], Self.K](Self.Step[o](self.function^, Pointer(to=env)), self.source^)


@fieldwise_init
struct _ReaderFoldStep[I: AnyType, R: AnyType, F: BinaryContract & Movable & Deinitable, o: ImmOrigin](MutableBinary):
    var function: Self.F
    var env: Pointer[Self.R, Self.o]
    comptime First = Self.F.First
    comptime Second = Self.F.Second
    comptime Action = _Action[Self.F.Out]
    comptime Out = Self.Action.Out[Self.o]
    comptime Error = _CommonError[Self.F.Error, Self.Action.Error[Self.o]]
    def call_mut(mut self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        comptime assert RepeatableBinary[Self.F] and Self.Action.Family == Self.I
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error] and _ErrorCompatible[Self.Error, Self.Action.Error[Self.o]]
        var action = rebind_var[Self.Action](_binary_repeated_as[Self.Error](self.function, first^, second^))
        return _reader_run_as[Self.Error](action^, rebind[Self.Action.Env](self.env[]))


@fieldwise_init
struct _ReaderFold[M: Monad, R: AnyType, V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator](ReaderAction):
    var prepare: Self.P
    var function: Self.F
    var initial: Self.K.Acc
    var source: Self.V
    comptime Family = ReaderT[Self.M, Self.R]
    comptime Env = Self.R
    comptime Value = Self.K.Acc
    comptime Step[o: ImmOrigin] = _ReaderFoldStep[Self.Family, Self.R, Self.F, o]
    comptime Out[o: ImmOrigin] = Self.M._Folded[Self.V, Self.P, Self.Step[o], Self.K]
    comptime Error[o: ImmOrigin] = Self.M._FoldError[Self.V, Self.P, Self.Step[o], Self.K]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) raises Self.Error[o] -> Self.Out[o]:
        return Self.M._fold[Self.V, Self.P, Self.Step[o], Self.K](self.prepare^, Self.Step[o](self.function^, Pointer(to=env)), self.initial^, self.source^)


@fieldwise_init
struct _ReaderChoice[M: Monad, A: ReaderAction, B: ReaderAction](
    ReaderAction, Copyable where conforms_to(A, Copyable) and conforms_to(B, Copyable)
):
    """One of two computations of one Reader family. Running it runs the
    selected branch; the base joins the two branches' carriers."""
    var value: Variant[Self.A, Self.B]
    comptime Family = Self.A.Family
    comptime Env = Self.A.Env
    comptime Value = Self.A.Value
    comptime Out[o: ImmOrigin] = Self.M._Joined[Self.A.Out[o], Self.B.Out[o]]
    comptime Error[o: ImmOrigin] = _CommonError[Self.A.Error[o], Self.B.Error[o]]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) raises Self.Error[o] -> Self.Out[o]:
        comptime E = Self.Error[o]
        comptime assert Self.B.Family == Self.A.Family and Self.B.Env == Self.A.Env, _CHOICE_FAMILY
        comptime assert Self.B.Value == Self.A.Value, _CHOICE_VALUE
        comptime assert _ErrorCompatible[E, Self.A.Error[o]] and _ErrorCompatible[E, Self.B.Error[o]]
        var value = self.value^
        if value.isa[Self.A]():
            var left = _reader_run_as[E](value^.unsafe_unwrap[Self.A](), rebind[Self.A.Env](env))
            return Self.M._join_left[Self.A.Out[o], Self.B.Out[o]](left^)
        var right = _reader_run_as[E](value^.unsafe_unwrap[Self.B](), rebind[Self.B.Env](env))
        return Self.M._join_right[Self.A.Out[o], Self.B.Out[o]](right^)


@fieldwise_init
struct _ReaderHoist[A: Movable & Deinitable, S: ReaderAction, H: _CarrierOp](
    ReaderAction, Copyable where conforms_to(S, Copyable) and conforms_to(H, Copyable)
):
    """Run the source, then apply one admitted base-carrier operation."""
    var source: Self.S
    var operation: Self.H
    comptime Family = Self.S.Family
    comptime Env = Self.S.Env
    comptime Value = Self.A
    comptime Out[o: ImmOrigin] = Self.H.Applied[Self.S.Out[o]]
    comptime Error[o: ImmOrigin] = _CommonError[Self.S.Error[o], Self.H.Error[Self.S.Out[o]]]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) raises Self.Error[o] -> Self.Out[o]:
        comptime E = Self.Error[o]
        comptime assert Self.H.Compatible[Self.S.Out[o]]
        comptime assert _ErrorCompatible[E, Self.S.Error[o]] and _ErrorCompatible[E, Self.H.Error[Self.S.Out[o]]]
        var base = _reader_run_as[E](self.source^, env)
        return _op_as[E](self.operation^, base^)


struct ReaderT[M: Monad, R: AnyType](_ReaderFamily, Local, _LocalLifting, ApplicativeError where conforms_to(M, ApplicativeError)):
    """Reader over the base Monad `M`: a computation borrows an environment `R` when run and returns an `M` carrier.

    Every operation returns a concrete computation that stores its inputs; a
    composed computation's type is the tree of its operations, and nothing runs
    until `run`. Constructing a computation does not raise; its run raises the
    exact common error of the stages it executes. On Mojo 1.1 that error cannot
    propagate from a function declared with a plain `raises`; handle it with
    `try`/`except`, where it keeps its exact type. The base is used only through
    its Monad methods and, for recovery, its optional ApplicativeError capability.
    Any Monad, including another Reader or State, can be
    the base. Traversal delegates to the base's `collect`, whose callback runs
    each produced computation with the borrowed environment.

    Parameters:
        M: The base Monad.
        R: The environment's type.
    """
    comptime Family = Self
    comptime AskAvailable = conforms_to(Self.R, Copyable)
    comptime Asked = _ReaderAsk[Self.M, downcast[Self.R, Copyable & Deinitable]]
    comptime AskError = Never
    comptime LocalCompatible[V: Movable & Deinitable] = _Action[V].Family == Self and _Action[V].Env == Self.R and _LocalIndependent[_Action[V]]
    comptime Localized[V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = _ReaderLocal[Self.M, downcast[Self.R, Movable & Deinitable], _Action[V], F]
    comptime LocalError[V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = Never
    comptime _HoistCompatible[V: Movable & Deinitable, H: _CarrierOp] = _Action[V].Family == Self and _Action[V].Env == Self.R and H.Compatible[_Action[V].Out[ImmUntrackedOrigin]] and H.Compatible[_Action[V].Out[ImmutAnyOrigin]] and _ErrorCompatible[_CommonError[_Action[V].Error[ImmUntrackedOrigin], H.Error[_Action[V].Out[ImmUntrackedOrigin]]], H.Error[_Action[V].Out[ImmUntrackedOrigin]]] and _ErrorCompatible[_CommonError[_Action[V].Error[ImmutAnyOrigin], H.Error[_Action[V].Out[ImmutAnyOrigin]]], H.Error[_Action[V].Out[ImmutAnyOrigin]]]
    comptime _Hoisted[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp] = _ReaderHoist[A, _Action[V], H]
    comptime _HoistError[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp] = Never
    comptime _Listening[C: Listen, A: Movable & Deinitable] = _ListenOp[C]
    @staticmethod
    def _hoist[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp](var op: H, var value: V) -> Self._Hoisted[A, V, H]:
        return Self._Hoisted[A, V, H](rebind_var[_Action[V]](value^), op^)

    comptime _ScopeCompatible[C: Local, V: Movable & Deinitable] = _Action[V].Family == Self and _Action[V].Env == Self.R and C.LocalCompatible[_Action[V].Out[ImmUntrackedOrigin]] and C.LocalCompatible[_Action[V].Out[ImmutAnyOrigin]]
    comptime _Scoped[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = Self._Hoisted[Self.Element[V], V, _LocalOp[C, F]]
    comptime _ScopeError[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = Never

    @staticmethod
    def ask() -> Self.Asked:
        """Construct a deferred copy of this Reader's environment.

        Returns:
            An environment-reading computation; requires AskAvailable.
        """
        comptime assert Self.AskAvailable
        return Self.Asked()

    @staticmethod
    def local[V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable](var f: F, var value: V) -> Self.Localized[V, F]:
        """Construct a scope for this Reader's own environment.

        Parameters:
            V: An admitted computation of this Reader family.
            F: A borrowing environment transformation.

        Args:
            f: The transformation, consumed.
            value: The computation, consumed.

        Returns:
            A deferred scope; the temporary environment cannot escape its run.
        """
        comptime assert Self.LocalCompatible[V], _FAMILY_MISMATCH
        return Self.Localized[V, F](rebind_var[_Action[V]](value^), f^)

    @staticmethod
    def _scope[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable](var f: F, var value: V) -> Self._Scoped[C, V, F]:
        """Transport a base scope through this Reader's execution boundary.

        Parameters:
            C: The selected base Local capability.
            V: This Reader's computation type.
            F: The selected environment transformation type.

        Args:
            f: The transformation, consumed.
            value: The computation, consumed.

        Returns:
            A Reader that scopes the base carrier produced when run.
        """
        comptime assert C.Family == Self.Base and Self._ScopeCompatible[C, V]
        return Self._hoist[Self.Element[V]](_LocalOp[C, F](f^), value^)

    comptime _Errors = downcast[Self.M, ApplicativeError]
    comptime Failure = Self._Errors.Failure
    comptime _ErrorCarrier[V: Movable & Deinitable] = _Action[V].Family == Self and _Action[V].Env == Self.R
    comptime Failed[A: Movable & Deinitable] = _ReaderFail[Self.M, Self.R, A]
    comptime FailError[A: Movable & Deinitable] = Never
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = _ReaderBind[Self.M, Self.R, _Action[V], H, True]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Never

    @staticmethod
    def fail[A: Movable & Deinitable](var error: Self.Failure) -> Self.Failed[A]:
        """Defer construction of the base failure until the Reader runs.

        Parameters:
            A: The absent success payload type.

        Args:
            error: The selected base error, consumed with its exact origins.

        Returns:
            A deferred computation; base failure construction runs only at run.
        """
        return Self.Failed[A](error^)

    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) -> Self.Handled[V, H]:
        """Recover the base error in the same borrowed environment when run.

        Parameters:
            V: The Reader computation of this family.
            H: The handler consuming the selected stored error and returning
                this family with the same success type; repeatable for branching.

        Args:
            handler: The handler, consumed and skipped on success.
            source: The source, consumed with its native origins.

        Returns:
            A deferred Reader that retains the environment borrow through its base.
        """
        comptime assert Self._Handles[V, H], "or_else: Reader family or payload mismatch"
        return Self.Handled[V, H](rebind_var[_Action[V]](source^), handler^)

    comptime Base = Self.M
    comptime Environment = Self.R
    comptime Element[V: Movable & Deinitable] = _Action[V].Value
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _ReaderMap[Self.M, Self.R, _Action[V], F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Never
    comptime Pure[A: Movable & Deinitable] = _ReaderPure[Self.M, Self.R, A]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = _ReaderCombine[Self.M, Self.R, _Action[V], F, G]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = Never
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _ReaderBind[Self.M, Self.R, _Action[V], F]
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Never
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _ReaderLoop[Self.M, Self.R, V, F, K]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Never
    comptime _Folded[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator] = _ReaderFold[Self.M, Self.R, V, P, F, K]
    comptime _FoldError[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator] = Never
    @staticmethod
    def _fold[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator](var prepare: P, var step: F, var initial: K.Acc, var source: V) -> Self._Folded[V, P, F, K]:
        return Self._Folded[V, P, F, K](prepare^, step^, initial^, source^)
    comptime _Joined[L: Movable & Deinitable, Q: Movable & Deinitable] = _ReaderChoice[Self.M, _Action[L], _Action[Q]]
    comptime Lifted[V: Movable & Deinitable] = _ReaderLift[Self.M, Self.R, V]
    comptime Endpoint[T: Movable & Deinitable, F: Movable & Deinitable] = _ReaderEndpoint[
        Self.M, Self.R, T, downcast[F, BorrowCallContract & Movable & Deinitable]]
    comptime LiftError[V: Movable & Deinitable] = Never

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) -> Self.Mapped[V, F]:
        """A Reader computation that maps the payload of `value` with `f` when run.

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
        """A Reader computation that ignores the environment and returns `value` in the base.

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
        """A Reader computation that runs both operands in the same environment and combines their payloads.

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
        """A Reader computation that runs `value`, then the computation `f` returns, in the same environment.

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
    def _join_left[L: Movable & Deinitable, Q: Movable & Deinitable](var value: L) -> Self._Joined[L, Q]:
        comptime assert _Action[L].Family == Self and _Action[Q].Family == Self, _CHOICE_FAMILY
        return Self._Joined[L, Q](Variant[_Action[L], _Action[Q]](rebind_var[_Action[L]](value^)))

    @staticmethod
    def _join_right[L: Movable & Deinitable, Q: Movable & Deinitable](var value: Q) -> Self._Joined[L, Q]:
        comptime assert _Action[L].Family == Self and _Action[Q].Family == Self, _CHOICE_FAMILY
        return Self._Joined[L, Q](Variant[_Action[L], _Action[Q]](rebind_var[_Action[Q]](value^)))

    @staticmethod
    def lift[V: Movable & Deinitable](var value: V) -> Self.Lifted[V]:
        """A Reader computation that ignores the environment and returns a base carrier.

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
        """A Reader computation from a callback that borrows the environment; `action[I, T](f)` calls this.

        Parameters:
            T: The payload type.
            F: The callback's type.

        Args:
            f: The callback, consumed.

        Returns:
            The computation.
        """
        comptime assert conforms_to(F, BorrowCallContract), "action: a Reader endpoint must borrow the environment"
        comptime D = downcast[F, BorrowCallContract & Movable & Deinitable]
        _admit_endpoint[Self.M, T, D.Result]()
        return Self.Endpoint[T, F](rebind_var[D](f^))


comptime Reader[R: AnyType] = ReaderT[IdentityFamily, R]
"""Reader over the bare value: a computation borrows an `R` and returns its payload.

Parameters:
    R: The environment's type.
"""


# Compatibility imports; public declarations live in capabilities.
from .capabilities import ask, local
