"""Reader: deferred computations over a borrowed environment and any base Monad.

Each operation is one struct whose run delegates to the base family. A result
that retains the environment, such as a bind over a deferred base, carries the
environment origin in its type.
"""
from std.builtin.rebind import rebind_var, downcast
from std.utils import Variant
from fp.algebra.protocols import Monad, _Lifting, _Accumulate
from fp.algebra.instances import IdentityFamily
from fp.callables.protocols import (UnaryContract, BinaryContract, ThunkContract, OnceUnary, MutableUnary,
                                    OnceThunk, BorrowCallContract, BorrowCallable, BorrowOnceCallable)
from fp.callables.invoke import call_once, call_repeated, RepeatableUnary
from fp.callables.native import _NativeBorrow, _Borrowing, _RaisingBorrowing
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from .protocols import ReaderAction, _ReaderFamily, _admit_endpoint, _FAMILY_MISMATCH, _CHOICE_FAMILY, _CHOICE_VALUE
from ._adapt import _reader_run_as, _map_as, _flat_map_as, _map2_lazy_as


comptime _Action[V: Movable & Deinitable] = downcast[V, ReaderAction]


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
        comptime if conforms_to(Self.F, BorrowOnceCallable):
            comptime D = downcast[Self.F, BorrowOnceCallable]
            return rebind_var[Self.Out[o]](rebind_var[D](self.function^).invoke_once(rebind[D.Payload](env)))
        else:
            comptime assert conforms_to(Self.F, BorrowCallable), "action: the endpoint must be a borrowed callable"
            comptime D = downcast[Self.F, BorrowCallable]
            return rebind_var[Self.Out[o]](rebind[D](self.function).invoke(rebind[D.Payload](env)))


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
struct _ReaderBind[M: Monad, R: AnyType, S: ReaderAction, F: UnaryContract & Movable & Deinitable](
    ReaderAction, Copyable where conforms_to(S, Copyable) and conforms_to(F, Copyable)
):
    var source: Self.S
    var function: Self.F
    comptime Family = ReaderT[Self.M, Self.R]
    comptime Env = Self.R
    comptime Value = _Action[Self.F.Out].Value
    comptime Next[o: ImmOrigin] = _ReaderContinue[Self.Family, Self.F, Self.R, o]
    comptime Out[o: ImmOrigin] = Self.M.Bound[Self.S.Out[o], Self.Next[o]]
    comptime Error[o: ImmOrigin] = _CommonError[Self.S.Error[o], Self.M.BindError[Self.S.Out[o], Self.Next[o]]]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) raises Self.Error[o] -> Self.Out[o]:
        comptime E = Self.Error[o]
        comptime assert _Action[Self.F.Out].Family == Self.Family, _FAMILY_MISMATCH
        comptime assert _ErrorCompatible[E, Self.S.Error[o]] and _ErrorCompatible[E, Self.M.BindError[Self.S.Out[o], Self.Next[o]]]
        var base = _reader_run_as[E](self.source^, rebind[Self.S.Env](env))
        return _flat_map_as[E, Self.M](Self.Next[o](self.function^, Pointer(to=env)), base^)


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
        var changed: Self.R
        try:
            comptime if conforms_to(Self.F, BorrowOnceCallable):
                comptime D = downcast[Self.F, BorrowOnceCallable]
                changed = rebind_var[Self.R](rebind_var[D](self.function^).invoke_once(rebind[D.Payload](env)))
            else:
                comptime D = downcast[Self.F, BorrowCallable]
                changed = rebind_var[Self.R](rebind[D](self.function).invoke(rebind[D.Payload](env)))
        except error:
            _propagate_error[E](error^)
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


struct ReaderT[M: Monad, R: AnyType](_ReaderFamily, _Lifting):
    """Reader over the base Monad `M`: a computation borrows an environment `R` when run and returns an `M` carrier.

    Every operation returns a concrete computation that stores its inputs; a
    composed computation's type is the tree of its operations, and nothing runs
    until `run`. Constructing a computation does not raise; its run raises the
    exact common error of the stages it executes. On Mojo 1.1 that error cannot
    propagate from a function declared with a plain `raises`; handle it with
    `try`/`except`, where it keeps its exact type. The base is used only through
    its `Monad` methods, so any Monad, including another Reader or State, can be
    the base. Traversal delegates to the base's `collect`, whose callback runs
    each produced computation with the borrowed environment.

    Parameters:
        M: The base Monad.
        R: The environment's type.
    """
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


def ask[I: _ReaderFamily]() -> _ReaderAsk[I.Base, downcast[I.Environment, Copyable & Deinitable]] where conforms_to(I.Environment, Copyable):
    """A Reader computation whose payload is a copy of the environment.

    Parameters:
        I: The Reader family; its environment must be `Copyable`.

    Returns:
        The computation.
    """
    return _ReaderAsk[I.Base, downcast[I.Environment, Copyable & Deinitable]]()


def local[S: ReaderAction, F: BorrowCallContract & Movable & Deinitable, //, I: _ReaderFamily](var f: F, var value: S
) -> _ReaderLocal[I.Base, downcast[I.Environment, Movable & Deinitable], S, F]:
    """A Reader computation that runs `value` with the environment `f` computes from the current one.

    The changed environment lives only for that run, so the base must not keep
    it; `local` over such a base is a compile error. Other overloads take a
    native function or closure that reads the current environment.

    Parameters:
        S: The computation's type.
        F: The callback's type: a `BorrowCallable` taking the environment.
        I: The Reader family.

    Args:
        f: The callback, consumed.
        value: The computation, consumed.

    Returns:
        The computation; nothing runs now.
    """
    comptime assert S.Family == I, _FAMILY_MISMATCH
    return _ReaderLocal[I.Base, downcast[I.Environment, Movable & Deinitable], S, F](value^, f^)


def local[S: ReaderAction, P: AnyType, R: Movable & Deinitable, //, I: _ReaderFamily, F: _Borrowing[P, R]](var f: F, var value: S
) -> _ReaderLocal[I.Base, downcast[I.Environment, Movable & Deinitable], S, _NativeBorrow[P, R, Never, F, False]] where P == I.Environment and R == I.Environment:
    """Run value with the environment a native function or closure computes from
    the current one, which it borrows."""
    return local[I](_NativeBorrow[P, R, Never, F, False](f^), value^)


def local[S: ReaderAction, P: AnyType, R: Movable & Deinitable, E: Movable & Deinitable, //, I: _ReaderFamily,
          F: _RaisingBorrowing[P, R, E]](var f: F, var value: S
) -> _ReaderLocal[I.Base, downcast[I.Environment, Movable & Deinitable], S, _NativeBorrow[P, R, E, F, True]] where P == I.Environment and R == I.Environment:
    """Raising form of the native local; its error type is kept."""
    return local[I](_NativeBorrow[P, R, E, F, True](f^), value^)
