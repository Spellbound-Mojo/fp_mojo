"""Lazy fallback for Optional payloads inside an explicitly selected base effect."""
from std.builtin.rebind import rebind_var
from fp.callables.protocols import ThunkContract, OnceUnary, MutableUnary
from fp.callables.invoke import RepeatableThunk, _OnceThunkAvailable
from fp.callables._receiver import _thunk_once_as, _ThunkView
from fp.callables.native import _NativeThunk, _Thunk, _RaisingThunk
from .collections import _SourceFamily
from std.builtin.rebind import downcast
from .protocols import Monad, _pure, _flat_map_as
from .instances import OptionalFamily
from ._primitive_contracts import BindContract
from ._branches import _optional_choose


@fieldwise_init
struct _AbsentFallback[I: Monad, A: Movable & Deinitable, F: ThunkContract & Movable & Deinitable, keep_optional: Bool](
    OnceUnary, MutableUnary where RepeatableThunk[F], Copyable where conforms_to(F, Copyable)
):
    var function: Self.F
    comptime Arg = Optional[Self.A]
    comptime Value = Optional[Self.A] if Self.keep_optional else Self.A
    comptime Present = Self.I.Pure[Self.Value]
    comptime Out = Self.I._Joined[Self.Present, Self.F.Out]
    comptime Error = Self.F.Error

    @staticmethod
    def _present(var value: Self.A) capturing -> Self.Out:
        comptime if Self.keep_optional:
            comptime assert Self.Value == Optional[Self.A]
            return Self.I._join_left[Self.Present, Self.F.Out](_pure[Self.I](rebind_var[Self.Value](Optional(value^))))
        else:
            comptime assert Self.Value == Self.A
            return Self.I._join_left[Self.Present, Self.F.Out](_pure[Self.I](rebind_var[Self.Value](value^)))

    @staticmethod
    def _absent(var function: Self.F) raises Self.Error capturing -> Self.Out:
        return Self.I._join_right[Self.Present, Self.F.Out](_thunk_once_as[Self.Error](function^))

    def call_once(deinit self, var source: Self.Arg) raises Self.Error -> Self.Out:
        return _optional_choose[Self.A, Self.Out, Self.F, Self._present, Self._absent](source^, self.function^)

    def call_mut(mut self, var source: Self.Arg) raises Self.Error -> Self.Out:
        comptime View = _ThunkView[Self.F, origin_of(self.function)]
        comptime Next = _AbsentFallback[Self.I, Self.A, View, Self.keep_optional]
        comptime assert Next.Out == Self.Out
        return rebind_var[Self.Out](Next(View(Pointer(to=self.function))).call_once(source^))


struct AbsenceContract[I: Monad, V: Movable & Deinitable, F: ThunkContract & Movable & Deinitable, keep_optional: Bool = True]:
    """Admission and exact types of lazy fallback inside a base Monad.

    Parameters:
        I: The base family carrying an Optional payload.
        V: The exact source carrier, including its native origins.
        F: The fallback factory, consumed or repeated according to the base.
        keep_optional: Retain Optional for or_else_absent; remove it for get_or_else_effect.
    """
    comptime Value = OptionalFamily.Element[Self.I.Element[Self.V]]
    """The present Optional payload type."""
    comptime Continuation = _AbsentFallback[Self.I, Self.Value, Self.F, Self.keep_optional]
    """The shared absence continuation used by the base bind."""
    comptime Operation = BindContract[Self.I, Self.V, Self.Continuation]
    """The selected family's bind contract."""
    comptime Compatible = (
        Self.I.CarrierCompatible[Self.V] and
        Self.I.Element[Self.V] == Optional[Self.Value] and
        Self.I.CarrierCompatible[Self.F.Out] and
        Self.I.Element[Self.F.Out] == Self.Continuation.Value and
        Self.I._JoinCompatible[Self.Continuation.Present, Self.F.Out] and
        _OnceThunkAvailable[Self.F] and Self.Operation.InvocationCompatible
    )
    """Exact Optional shape, fallback payload, branch join and receiver admission."""
    comptime Out = Self.Operation.Out
    """The base carrier of the selected present or fallback value."""
    comptime Error = Self.Operation.Error
    """The exact construction error; deferred errors remain deferred."""


def _fallback[I: Monad, V: Movable & Deinitable, F: ThunkContract & Movable & Deinitable, keep_optional: Bool](
    var function: F, var source: V
) raises AbsenceContract[I, V, F, keep_optional].Error -> AbsenceContract[I, V, F, keep_optional].Out:
    comptime C = AbsenceContract[I, V, F, keep_optional]
    return _flat_map_as[C.Error, I](C.Continuation(function^), source^)


def or_else_absent[V: Movable & Deinitable, F: ThunkContract & Movable & Deinitable, //, I: Monad = downcast[_SourceFamily[V], Monad]](
    var fallback: F, var source: V
) raises AbsenceContract[I, V, F].Error -> AbsenceContract[I, V, F].Out where AbsenceContract[I, V, F].Compatible:
    """Use a lazy effectful fallback only for an absent Optional payload.

    Select the base Monad: IdentityFamily for a native Optional, State for a
    State of Optional, or the base of OptionalT. Present payloads move through
    unchanged. Base failures skip the fallback; earlier state and output stay
    visible. A branching base calls a repeatable factory for each absent branch.
    This does not recover stored errors or native exceptions.

    Parameters:
        V: The base carrier of Optional[A].
        F: A factory returning a base carrier of Optional[A].
        I: The base Monad, not the OptionalT layer over it; defaults to the source's family.

    Args:
        fallback: The factory, consumed; skipped on presence or base failure.
        source: The original base carrier, consumed.

    Returns:
        The base carrier of the selected Optional.

    Raises:
        The base bind's exact native error, at its usual execution boundary.
    """
    return _fallback[I, V, F, True](fallback^, source^)


def get_or_else_effect[V: Movable & Deinitable, F: ThunkContract & Movable & Deinitable, //, I: Monad = downcast[_SourceFamily[V], Monad]](
    var fallback: F, var source: V
) raises AbsenceContract[I, V, F, False].Error -> AbsenceContract[I, V, F, False].Out where AbsenceContract[I, V, F, False].Compatible:
    """Remove Optional by keeping a present value or running a lazy base effect.

    Selection and branching follow or_else_absent. The fallback returns an
    effect of A, so the final carrier no longer contains the Optional layer.

    Parameters:
        V: The base carrier of Optional[A].
        F: A factory returning a base carrier of A.
        I: The base Monad; defaults to the source's family.

    Args:
        fallback: The factory, consumed; called only on an absent payload.
        source: The base carrier, consumed.

    Returns:
        A carrier of A in the base family.

    Raises:
        The exact native bind error, preserving deferred execution.
    """
    return _fallback[I, V, F, False](fallback^, source^)


def or_else_absent[V: Movable & Deinitable, R: Movable & Deinitable, F: _Thunk[R], //, I: Monad = downcast[_SourceFamily[V], Monad]](var fallback: F, var source: V
) raises AbsenceContract[I, V, _NativeThunk[R, Never, F, False], True].Error -> AbsenceContract[I, V, _NativeThunk[R, Never, F, False], True].Out where AbsenceContract[I, V, _NativeThunk[R, Never, F, False], True].Compatible:
    """Select a fallback supplied as an owned native function or closure."""
    return or_else_absent[I](_NativeThunk[R, Never, F, False](fallback^), source^)


def or_else_absent[V: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, F: _RaisingThunk[R, E], //, I: Monad = downcast[_SourceFamily[V], Monad]](var fallback: F, var source: V
) raises AbsenceContract[I, V, _NativeThunk[R, E, F, True], True].Error -> AbsenceContract[I, V, _NativeThunk[R, E, F, True], True].Out where AbsenceContract[I, V, _NativeThunk[R, E, F, True], True].Compatible:
    """Select a fallback supplied as an owned native function or closure."""
    return or_else_absent[I](_NativeThunk[R, E, F, True](fallback^), source^)


def get_or_else_effect[V: Movable & Deinitable, R: Movable & Deinitable, F: _Thunk[R], //, I: Monad = downcast[_SourceFamily[V], Monad]](var fallback: F, var source: V
) raises AbsenceContract[I, V, _NativeThunk[R, Never, F, False], False].Error -> AbsenceContract[I, V, _NativeThunk[R, Never, F, False], False].Out where AbsenceContract[I, V, _NativeThunk[R, Never, F, False], False].Compatible:
    """Select a fallback supplied as an owned native function or closure."""
    return get_or_else_effect[I](_NativeThunk[R, Never, F, False](fallback^), source^)


def get_or_else_effect[V: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, F: _RaisingThunk[R, E], //, I: Monad = downcast[_SourceFamily[V], Monad]](var fallback: F, var source: V
) raises AbsenceContract[I, V, _NativeThunk[R, E, F, True], False].Error -> AbsenceContract[I, V, _NativeThunk[R, E, F, True], False].Out where AbsenceContract[I, V, _NativeThunk[R, E, F, True], False].Compatible:
    """Select a fallback supplied as an owned native function or closure."""
    return get_or_else_effect[I](_NativeThunk[R, E, F, True](fallback^), source^)
