"""Application recipe names and native admission over canonical machine owners."""
from std.builtin.rebind import downcast
from fp.effects import ExitCase
from fp.effects._io_core import IOContract, DelayContract
from fp.effects.protocols import ReaderAction
from fp.callables import UnaryContract, ThunkContract
from fp.callables.invoke import _OnceUnaryAvailable
from fp.callables.native import _NativeThunk, _Thunk, _RaisingThunk, NativeUnary, _Unary, _RaisingUnary
from fp._internal.errors import _ErrorCompatible
from .kernel import Machine as _CoreMachine, Sleep as _Sleep
from .time import Duration, Instant
from .family import Async, Machine, _Recipe
from fp.algebra import TailRecContract
from .composition import Pure as _Pure, Bind as _Bind, Loop as _Loop, pure as _pure
from .children import Both as _Both, both as _both, ScopedBoth, scoped_both
from .scopes import Scope as _Scope, ScopedMachine, CleanupMachine, _ProgramUse
from .racing import Timeout as _Timeout, timeout_after as _timeout_after, timeout_to as _timeout_to, Race as _Race, RaceResult, race as _race, race_first as _race_first
from .io import EvalIO as _EvalIO, eval_io as _eval_io, delay as _delay
from .finalization import Guarantee as _Guarantee, Masked as _Masked, Poll, _ConstantMask
from .finalization import guarantee as _guarantee, guarantee_case as _guarantee_case, on_cancel as _on_cancel, uncancelable as _uncancelable, uncancelable_with as _uncancelable_with
from .callbacks import Callback as _Callback, Completion, _CompletionType, _CallbackUnit, callback as _callback

comptime Pure[T: Movable & Deinitable, E: Movable & Deinitable] = _Recipe[_Pure[T, E]]
"""An unopened recipe owning an already evaluated value.

Only the logical parameters and machine protocol are supported, not storage layout.

Parameters:
    T: The owned value type, including external origins.
    E: The exact domain error type.
"""
comptime Bind[P: Machine, F: UnaryContract & Movable & Deinitable] = Async[P.Error].Bound[P, F]
"""The concrete recipe returned by selected Async flat_map.

Only the logical parameters and machine protocol are supported, not storage layout.

Parameters:
    P: The source machine.
    F: The owned continuation returning a machine in the same error family.
"""
comptime Loop[F: UnaryContract & Movable & Deinitable] = TailRecContract[Async[downcast[F.Out, _CoreMachine].Error], F].Out
"""The concrete tail_rec_m recipe in the step machine's Async family.

Only the logical parameters and machine protocol are supported, not storage layout.

Parameters:
    F: The repeatable step returning a machine whose value is ControlFlow.
"""
comptime Both[P: Machine, Q: Machine] = _Recipe[_Both[P, Q]]
"""A pair recipe that drains both child subtrees before completion.

Only the logical parameters and machine protocol are supported, not storage layout.

Parameters:
    P: The left child type.
    Q: The right child type, with exactly the same error type.
"""
comptime Scope[A: Machine, U: ScopedMachine, C: CleanupMachine] = _Recipe[_Scope[A, U, C]]
"""A recipe owning acquisition, fresh per-poll resource loans and release.

Only the logical parameters and machine protocol are supported, not storage layout.

Parameters:
    A: The acquisition machine.
    U: The scoped body type.
    C: The cleanup type, borrowing the resource and exact exit.
"""
comptime RaceFirst[P: Machine, Q: Machine] = _Recipe[_Race[P, Q]]
"""The race recipe selecting the first observed terminal outcome.

Only the logical parameters and machine protocol are supported, not storage layout.

Parameters:
    P: The left child type.
    Q: The right child type, with exactly the same error type.
"""
comptime Race[P: Machine, Q: Machine] = _Recipe[_Race[P, Q, 1]]
"""The race recipe using the other drained outcome after cancellation-only wins.

Only the logical parameters and machine protocol are supported, not storage layout.

Parameters:
    P: The left child type.
    Q: The right child type, with exactly the same error type.
"""
comptime EvalIO[P: ReaderAction] = _Recipe[_EvalIO[P]]
"""A synchronous IO endpoint executed in one poll under the inherited context.

Only the logical parameters and machine protocol are supported, not storage layout.

Parameters:
    P: The compatible synchronous IO recipe type.
"""
comptime Delay[F: ThunkContract & Movable & Deinitable, E: Movable & Deinitable] = EvalIO[DelayContract[F, E].Out]
"""The concrete delayed recipe for a library thunk.

Only the logical parameters and machine protocol are supported, not storage layout.

Parameters:
    F: The owned thunk descriptor, invoked once after entry.
    E: The selected domain error; it admits the thunk error or Never.
"""
comptime NativeDelay[T: Movable & Deinitable, E: Movable & Deinitable, F: Movable & Deinitable, X: Movable & Deinitable = Never, raising: Bool = False] = Delay[_NativeThunk[T, X, F, raising], E]
"""The concrete delayed recipe for an owned native function or closure.

Only the logical parameters and machine protocol are supported, not storage layout.

Parameters:
    T: The callback result.
    E: The selected domain error.
    F: The exact native callable type, including captures.
    X: The callback's native error, Never by default.
    raising: Whether the native signature declares raises, false by default.
"""
comptime Guarantee[P: Machine, Q: Machine] = _Recipe[_Guarantee[P, _ProgramUse[Q, ExitCase[P.Error]]]]
"""A recipe retaining the body result until owned cleanup finishes.

Only the logical parameters and machine protocol are supported, not storage layout.

Parameters:
    P: The body machine.
    Q: The cleanup machine; its successful value is discarded.
"""
comptime OnCancel[P: Machine, Q: Machine] = _Recipe[_Guarantee[P, _ProgramUse[Q, ExitCase[P.Error]], True]]
"""A recipe selecting cleanup when the body exit records cancellation.

Only the logical parameters and machine protocol are supported, not storage layout.

Parameters:
    P: The body machine.
    Q: The cleanup machine in the same exact error family.
"""
comptime GuaranteeCase[P: Machine, F: ScopedMachine] = _Recipe[_Guarantee[P, F]]
"""A recipe lending its exact exit case to resumable cleanup.

Only the logical parameters and machine protocol are supported, not storage layout.

Parameters:
    P: The body machine.
    F: The scoped cleanup, borrowing ExitCase[P.Error] each poll.
"""
comptime Masked[F: UnaryContract & Movable & Deinitable, E: Movable & Deinitable] = _Recipe[_Masked[F, E]]
"""The recipe built by a lexical masking factory.

Only the logical parameters and machine protocol are supported, not storage layout.

Parameters:
    F: A once-callable consuming Poll[E] and returning a machine.
    E: The exact domain error type.
"""
comptime Uncancelable[P: Machine] = Masked[_ConstantMask[P], P.Error]
"""A recipe running owned work under a fresh lexical cancellation mask.

Only the logical parameters and machine protocol are supported, not storage layout.

Parameters:
    P: The body machine type.
"""
comptime Callback[F: UnaryContract & Movable & Deinitable, C: Machine] = _Recipe[_Callback[F, C]]
"""A registration scope retaining withdrawal ownership through completion.

Only the logical parameters and machine protocol are supported, not storage layout.

Parameters:
    F: The once-callable accepting a Completion and returning native no result or explicit NoneType.
    C: The owned withdrawal machine yielding native no result or explicit NoneType, with the same error.
"""


def pure[E: Movable & Deinitable, T: Movable & Deinitable](var value: T) -> Pure[T, E]:
    """Own an already evaluated value without running a callback.

    Parameters:
        E: The selected domain error.
        T: The owned value type.

    Args:
        value: The value, consumed once.

    Returns:
        An unopened recipe in Async[E].
    """
    return _Recipe(_pure[E](value^))


def both[P: Machine, Q: Machine](var left: P, var right: Q) -> Both[P, Q] where P.Error == Q.Error:
    """Cooperatively run two children and drain both before returning.

    Parameters:
        P: The left machine.
        Q: The right machine with the same exact error.

    Args:
        left: The owned left recipe.
        right: The owned right recipe.

    Returns:
        A recipe yielding the pair of values; failures retain left-before-right error order.
    """
    return _Recipe(_both(left^, right^))


def scope[A: Machine, U: ScopedMachine, C: CleanupMachine](var acquire: A, var use: U, var release: C) -> Scope[A, U, C] where A.Value == U.Input and A.Value == C.Input and A.Error == U.Error and A.Error == C.Error:
    """Acquire masked, lend the resource afresh to each body poll, then release masked.

    Parameters:
        A: The acquisition machine.
        U: The scoped body, with exact resource input and error.
        C: The cleanup, with exact resource input and error.

    Args:
        acquire: The unopened acquisition.
        use: The body receiving fresh resource loans.
        release: Owned cleanup, also borrowing the exact exit.

    Returns:
        A recipe that retains resource and successful body values until release completes.
    """
    return _Recipe(_Scope(acquire^, use^, release^))


def race_first[P: Machine, Q: Machine](var left: P, var right: Q) -> RaceFirst[P, Q] where P.Error == Q.Error:
    """Select the first observed terminal outcome, then cancel and drain the other child.

    Parameters:
        P: The left machine.
        Q: The right machine with the same exact error.

    Args:
        left: The owned left recipe.
        right: The owned right recipe.

    Returns:
        A tagged successful value, failure or cancellation; losing errors remain in the outcome.
    """
    return _Recipe(_race_first(left^, right^))


def race[P: Machine, Q: Machine](var left: P, var right: Q) -> Race[P, Q] where P.Error == Q.Error:
    """After a cancellation-only first outcome, use the other child's drained outcome.

    Parameters:
        P: The left machine.
        Q: The right machine with the same exact error.

    Args:
        left: The owned left recipe.
        right: The owned right recipe.

    Returns:
        A recipe retaining all subtree errors; both children are canceled and drained as required.
    """
    return _Recipe(_race(left^, right^))


def eval_io[P: ReaderAction](var program: P) -> EvalIO[P] where IOContract[P].Compatible:
    """Bridge a compatible synchronous IO recipe through the inherited async context.

    Parameters:
        P: The compatible IO recipe type.

    Args:
        program: The owned synchronous endpoint.

    Returns:
        A one-poll recipe; blocking endpoint code still blocks that poll.
    """
    return _Recipe(_eval_io(program^))


def delay[F: ThunkContract & Movable & Deinitable, //, E: Movable & Deinitable](var function: F) -> Delay[F, E] where DelayContract[F, E].Compatible:
    """Defer a synchronous callback and capture its compatible native error during execution.

    Parameters:
        F: The owned once-admitted thunk descriptor.
        E: The selected domain error.

    Args:
        function: The thunk, consumed without invoking it.

    Returns:
        An unopened recipe; this does not offload or preempt a blocking callback.
    """
    return _Recipe(_delay[E](function^))


def delay[T: Movable & Deinitable, //, E: Movable & Deinitable, F: _Thunk[T]](var function: F) -> NativeDelay[T, E, F]:
    """Adapt an owned native callback through the canonical callable boundary."""
    return delay[E](_NativeThunk[T, Never, F, False](function^))


def delay[T: Movable & Deinitable, X: Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingThunk[T, X]](var function: F) -> NativeDelay[T, E, F, X, True] where _ErrorCompatible[E, X]:
    """Adapt an owned native callback through the canonical callable boundary."""
    return delay[E](_NativeThunk[T, X, F, True](function^))



# Native thin signatures need explicit register-result evidence or a borrowed
# symbolic admission boundary. Admission copies the pointer into _NativeThunk;
# its canonical invocation owner preserves the exact ABI and error type.
def delay[T: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable](ref[o] function: def() thin -> T) -> NativeDelay[T, E, type_of(function), Never, False]:
    """Own a thin function pointer through the canonical native thunk adapter."""
    return delay[E](_NativeThunk[T, Never, type_of(function), False](function))


def delay[T: RegisterPassable & Deinitable, //, E: Movable & Deinitable](function: def() thin -> T) -> NativeDelay[T, E, type_of(function), Never, False]:
    """Own a thin function pointer through the canonical native thunk adapter."""
    return delay[E](_NativeThunk[T, Never, type_of(function), False](function))


def delay[E: Movable & Deinitable](function: def() thin) -> NativeDelay[type_of(None), E, type_of(function), Never, False]:
    """Own a thin function pointer through the canonical native thunk adapter."""
    return delay[E](_NativeThunk[type_of(None), Never, type_of(function), False](function))


def delay[T: Movable & Deinitable, o: ImmOrigin, X: Movable & Deinitable, //, E: Movable & Deinitable](ref[o] function: def() raises X thin -> T) -> NativeDelay[T, E, type_of(function), X, True] where _ErrorCompatible[E, X]:
    """Own a thin function pointer through the canonical native thunk adapter."""
    return delay[E](_NativeThunk[T, X, type_of(function), True](function))


def delay[T: RegisterPassable & Deinitable, X: Movable & Deinitable, //, E: Movable & Deinitable](function: def() raises X thin -> T) -> NativeDelay[T, E, type_of(function), X, True] where _ErrorCompatible[E, X]:
    """Own a thin function pointer through the canonical native thunk adapter."""
    return delay[E](_NativeThunk[T, X, type_of(function), True](function))


def delay[X: Movable & Deinitable, //, E: Movable & Deinitable](function: def() raises X thin) -> NativeDelay[type_of(None), E, type_of(function), X, True] where _ErrorCompatible[E, X]:
    """Own a thin function pointer through the canonical native thunk adapter."""
    return delay[E](_NativeThunk[type_of(None), X, type_of(function), True](function))


def guarantee[P: Machine, Q: Machine](var program: P, var cleanup: Q) -> Guarantee[P, Q] where P.Error == Q.Error:
    """Drain owned cleanup after entry, retaining any successful body value meanwhile.

    Parameters:
        P: The body machine.
        Q: Cleanup in the same exact error family.

    Args:
        program: The owned body.
        cleanup: The owned cleanup; its successful value is discarded.

    Returns:
        A recipe preserving body-before-cleanup error order and the cancellation flag.
    """
    return _Recipe(_guarantee(program^, cleanup^))


def on_cancel[P: Machine, Q: Machine](var program: P, var cleanup: Q) -> OnCancel[P, Q] where P.Error == Q.Error:
    """Select owned cleanup when the body exit records cancellation.

    Parameters:
        P: The body machine.
        Q: Cleanup in the same exact error family.

    Args:
        program: The owned body.
        cleanup: Cleanup for cancellation-only or failure with cancellation.

    Returns:
        A recipe using the canonical scoped finalization policy.
    """
    return _Recipe(_on_cancel(program^, cleanup^))


def guarantee_case[P: Machine, F: ScopedMachine](var program: P, var cleanup: F) -> GuaranteeCase[P, F] where F.Input == ExitCase[P.Error] and P.Error == F.Error:
    """Lend the exact body exit to each cleanup poll without lending its success value.

    Parameters:
        P: The body machine.
        F: A scoped machine borrowing ExitCase[P.Error].

    Args:
        program: The owned body.
        cleanup: The owned finalizer, run masked.

    Returns:
        A recipe retaining body and cleanup errors without copying their payloads.
    """
    return _Recipe(_guarantee_case(program^, cleanup^))


def uncancelable[P: Machine](var program: P) -> Uncancelable[P]:
    """Run a recipe under a fresh lexical mask.

    Parameters:
        P: The owned body machine.

    Args:
        program: The unopened body.

    Returns:
        A masked recipe; pending cancellation remains observable at later unmasked checkpoints.
    """
    return _Recipe(_uncancelable(program^))


def uncancelable_with[F: UnaryContract & Movable & Deinitable, //, E: Movable & Deinitable](var factory: F) -> Masked[F, E] where _OnceUnaryAvailable[F] and F.Arg == Poll[E] and _ErrorCompatible[E, F.Error] and conforms_to(F.Out, Machine) and downcast[F.Out, Machine].Error == E:
    """Build masked work with a handle restoring this region's preceding cancellation state.

    Parameters:
        F: The owned once-callable factory accepting Poll[E].
        E: The exact domain error of the returned work.

    Args:
        factory: The deferred factory, consumed once.

    Returns:
        A masked recipe; escaped Poll handles cannot pierce another region or finalizer mask.
    """
    return _Recipe(_uncancelable_with[E](factory^))


def uncancelable_with[R: Machine, //, E: Movable & Deinitable, F: _Unary[Poll[E], R]](var factory: F) -> Masked[NativeUnary[Poll[E], R, Never, F, False], E] where R.Error == E:
    """Adapt an owned native callback through the canonical callable boundary."""
    return uncancelable_with[E](NativeUnary[Poll[E], R, Never, F, False](factory^))


def uncancelable_with[R: Machine, X: Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingUnary[Poll[E], R, X]](var factory: F) -> Masked[NativeUnary[Poll[E], R, X, F, True], E] where R.Error == E and _ErrorCompatible[E, X]:
    """Adapt an owned native callback through the canonical callable boundary."""
    return uncancelable_with[E](NativeUnary[Poll[E], R, X, F, True](factory^))


def callback[F: UnaryContract & Movable & Deinitable, C: Machine](var register: F, var withdrawal: C) -> Callback[F, C] where _OnceUnaryAvailable[F] and conforms_to(F.Arg, _CompletionType) and F.Arg == Completion[downcast[F.Arg, _CompletionType].Value, C.Error] and _CallbackUnit[F.Out] and _CallbackUnit[C.Value] and _ErrorCompatible[C.Error, F.Error]:
    """Register one completion source and retain owned withdrawal until it has drained.

    Parameters:
        F: The owned once-callable registration, returning native no result or explicit NoneType.
        C: The withdrawal machine, yielding unit in the same exact error family.

    Args:
        register: Synchronous registration receiving a Completion; compatible errors are captured.
        withdrawal: Owned cleanup after every entered registration, including success or registration failure.

    Returns:
        A recipe that becomes terminal only after withdrawal has discharged all external uses.
    """
    return _Recipe(_callback(register^, withdrawal^))


def callback[A: Movable & Deinitable, C: Machine, //, F: _Unary[A, NoneType]](var register: F, var withdrawal: C) -> Callback[NativeUnary[A, NoneType, Never, F, False], C] where conforms_to(A, _CompletionType) and A == Completion[downcast[A, _CompletionType].Value, C.Error] and _CallbackUnit[C.Value]:
    """Adapt an owned native callback through the canonical callable boundary."""
    return callback(NativeUnary[A, NoneType, Never, F, False](register^), withdrawal^)


def callback[A: Movable & Deinitable, X: Movable & Deinitable, C: Machine, //, F: _RaisingUnary[A, NoneType, X]](var register: F, var withdrawal: C) -> Callback[NativeUnary[A, NoneType, X, F, True], C] where conforms_to(A, _CompletionType) and A == Completion[downcast[A, _CompletionType].Value, C.Error] and _CallbackUnit[C.Value] and _ErrorCompatible[C.Error, X]:
    """Adapt an owned native callback through the canonical callable boundary."""
    return callback(NativeUnary[A, NoneType, X, F, True](register^), withdrawal^)


comptime Sleep[E: Movable & Deinitable] = _Recipe[_Sleep[E]]
"""An unopened timer recipe using checked relative time.

Parameters:
    E: The exact domain error; timer setup introduces no domain failure.
"""
comptime TimeoutAfter[P: Machine, Q: Machine] = _Recipe[_Timeout[P, Q]]
"""A timeout retaining the preserved first-terminal selection policy.

Parameters:
    P: The source machine.
    Q: The fallback machine with the same value and error types.
"""
comptime TimeoutTo[P: Machine, Q: Machine] = _Recipe[_Timeout[P, Q, True]]
"""A timeout preferring a source result after required draining.

Parameters:
    P: The source machine.
    Q: The fallback machine with the same value and error types.
"""


def sleep[E: Movable & Deinitable](duration: Duration) -> Sleep[E]:
    """Wait cooperatively from entry using a checked relative duration.

    Parameters:
        E: The exact selected domain error.

    Args:
        duration: A nonnegative checked duration, copied into the unopened timer.

    Returns:
        A cancelable unit recipe whose absolute deadline uses opaque Instant.
    """
    return _Recipe(_Sleep[E](duration._nanoseconds))


def timeout_after[P: Machine, Q: Machine](var program: P, duration: Duration, var fallback: Q) -> TimeoutAfter[P, Q] where P.Error == Q.Error and P.Value == Q.Value:
    """Choose by first terminal outcome, draining the source before fallback entry.

    Parameters:
        P: The source machine.
        Q: The fallback with exactly the same value and error types.

    Args:
        program: The unopened source, consumed once.
        duration: The checked relative duration anchored when the timeout enters.
        fallback: Owned fallback, entered only after the selected timeout and draining.

    Returns:
        A structured timeout retaining all source and cleanup errors.
    """
    return _Recipe(_timeout_after(program^, duration._nanoseconds, fallback^))


def timeout_to[P: Machine, Q: Machine](var program: P, duration: Duration, var fallback: Q) -> TimeoutTo[P, Q] where P.Error == Q.Error and P.Value == Q.Value:
    """After the timer wins, prefer the drained source outcome when available.

    Parameters:
        P: The source machine.
        Q: The fallback with exactly the same value and error types.

    Args:
        program: The unopened source, consumed once.
        duration: The checked relative duration anchored on entry.
        fallback: Owned fallback used after timer victory and cancellation-only
            source completion; parent cancellation still prevents its entry.

    Returns:
        A structured timeout preserving all subtree errors and cleanup ownership.
    """
    return _Recipe(_timeout_to(program^, duration._nanoseconds, fallback^))
