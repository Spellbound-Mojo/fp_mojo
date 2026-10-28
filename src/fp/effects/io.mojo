"""Concrete IO recipes over the existing Reader, Result and Optional families."""
from std.atomic import Atomic
from std.memory import ArcPointer
from std.time import monotonic, sleep
from std.math import isfinite, min
from std.builtin.rebind import downcast, rebind_var
from fp.algebra.instances import OptionalFamily
from fp.callables.protocols import OnceThunk, ThunkContract, BorrowCallContract
from fp.callables.invoke import _OnceThunkAvailable
from fp.callables._receiver import _OnceBorrowAvailable
from fp.callables._binding import _OwnedThunk
from fp.callables.native import _NativeThunk, _Thunk, _RaisingThunk, _NativeBorrow, _Borrowing, _RaisingBorrowing
from fp.data import Result, Ok, Err
from fp._internal.errors import _ErrorCompatible
from .protocols import ReaderAction
from .reader import ReaderT, _LocalIndependent
from .layers import ResultT
from .outcomes import EffectFailure, Outcome, _capture, _finish
from .resources import Resource, _OpenScope


struct CancellationToken(Copyable):
    """A shared atomic cancellation request; cancellation is cooperative.

    Copies share one flag. Requesting cancellation never kills a thread or
    interrupts native code. IO observes it at its documented checkpoints.
    """
    var _flag: ArcPointer[Atomic[UInt8]]
    def __init__(out self):
        self._flag = ArcPointer(Atomic(UInt8(0)))

    def cancel(self):
        """Request cancellation for every computation using this token."""
        self._flag[].store(1)

    def requested(self) -> Bool:
        """Read whether cancellation was requested, without resetting it.

        Returns:
            True after any copy receives cancel.
        """
        return self._flag[].load() != 0


trait _IOContextType:
    comptime NativeError: Movable & Deinitable


@fieldwise_init
struct IOContext[E: Movable & Deinitable](_IOContextType, Copyable):
    """A borrowed execution context for custom IO endpoints.

    Masking is local to a context value; token copies share only the atomic
    request. Custom endpoints must honor cancellation cooperatively and return
    the documented Outcome shape without borrowing this temporary context.

    Parameters:
        E: The exact native error type selected by IO.
    """
    comptime NativeError = Self.E
    """The native error type, before EffectFailure aggregation."""
    var _token: CancellationToken
    var _masked: Bool

    def canceled(self) -> Bool:
        """Check cancellation at this context's current masking level.

        Returns:
            True only when cancellation is both requested and unmasked.
        """
        return not self._masked and self._token.requested()

    def request_cancel(self):
        """Request cancellation, even if observation is currently masked."""
        self._token.cancel()

    def _mask(self) -> Self:
        return Self(self._token.copy(), True)


comptime IO[E: Movable & Deinitable = Error] = ReaderT[ResultT[OptionalFamily, EffectFailure[E]], IOContext[E]]
"""A deferred, typed IO family using the existing Monad and error operations.

Use delay, pure[IO[E]], map, flat_map and tail_rec_m to construct recipes;
run_io consumes one at the host boundary. Native callbacks run synchronously.
Cancellation uses the outer Optional and cannot be recovered as a stored error.

Parameters:
    E: The exact native error payload type; Error by default.
"""


struct IOContract[P: ReaderAction]:
    """Admission and exact outcome type for running a concrete IO recipe.

    Parameters:
        P: The program type, retaining all callback and payload origins.
    """
    comptime Error = downcast[Self.P.Env, _IOContextType].NativeError
    """The selected native error type, inferred from the program context."""
    comptime Out = Outcome[Self.P.Value, Self.Error]
    """The success, accumulated failure, or cancellation outcome."""
    comptime Compatible = Self.P.Family == IO[Self.Error] and _LocalIndependent[Self.P] and _ErrorCompatible[Self.Error, Self.P.Error[ImmUntrackedOrigin]] and Self.P.Out[ImmUntrackedOrigin] == Self.Out
    """Exact family membership and errors, with no temporary context escape."""


@fieldwise_init
struct _RunIO[P: ReaderAction, o: ImmOrigin](OnceThunk):
    var program: Self.P
    var context: Pointer[Self.P.Env, Self.o]
    comptime Out = Self.P.Out[Self.o]
    comptime Error = Self.P.Error[Self.o]
    def call_once(deinit self) raises Self.Error -> Self.Out:
        return self.program^.run(self.context[])


def _settle[T: Movable & Deinitable, E: Movable & Deinitable](var value: Outcome[T, E], context: IOContext[E]) -> Outcome[T, E]:
    if not value:
        return None
    var result = value.take()
    if result.is_err():
        var failure = result^._take_err()
        failure.canceled = failure.canceled or context.canceled()
        return Optional(Result[T, EffectFailure[E]](Err(failure^)))
    if context.canceled():
        return None
    return Optional(result^)


def _run_io[P: ReaderAction, o: ImmOrigin](var program: P, ref[o] context: IOContext[IOContract[P].Error]
) -> IOContract[P].Out where IOContract[P].Compatible:
    comptime E = IOContract[P].Error
    if context.canceled():
        return None
    comptime assert P.Env == IOContext[E] and _ErrorCompatible[E, P.Error[o]]
    var captured = _capture[E](_RunIO[P, o](program^, Pointer(to=rebind[P.Env](context))))
    if captured.is_err():
        return _settle(Optional(Result[P.Value, EffectFailure[E]](Err(captured^._take_err()))), context)
    comptime assert P.Out[o] == IOContract[P].Out
    return _settle(rebind_var[IOContract[P].Out](captured^._take_ok()), context)


@fieldwise_init
struct _IODelay[E: Movable & Deinitable, F: ThunkContract & Movable & Deinitable](ReaderAction):
    var function: Self.F
    comptime Family = IO[Self.E]
    comptime Value = Self.F.Out
    comptime Env = IOContext[Self.E]
    comptime Out[o: ImmOrigin] = Outcome[Self.Value, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        if env.canceled():
            return None
        comptime assert _ErrorCompatible[Self.E, Self.F.Error]
        return _settle(Optional(_capture[Self.E](_OwnedThunk(self.function^))), env)


def delay[F: ThunkContract & Movable & Deinitable, //, E: Movable & Deinitable](var function: F
) -> _IODelay[E, F] where _ErrorCompatible[E, F.Error] and _OnceThunkAvailable[F]:
    """Suspend one native callback, capturing its exact error at execution.

    No callback runs at construction. Cancellation is checked before and after
    it runs; arbitrary native code is not preempted. A late cancellation may
    discard a success, but never discards a raised error. Completed external
    effects are not rolled back. The concrete callback owner moves exactly once.

    Parameters:
        F: A once-callable thunk; shared and mutable receivers are also admitted.
        E: The selected IO error type; F raises E or Never.

    Args:
        function: The callback, moved into the unopened recipe.

    Returns:
        An IO[E] program yielding F.Out.
    """
    return _IODelay[E, F](function^)


def delay[T: Movable & Deinitable, //, E: Movable & Deinitable, F: _Thunk[T]](var function: F
) -> _IODelay[E, _NativeThunk[T, Never, F, False]]:
    """Suspend an owned non-raising native function or closure."""
    return delay[E](_NativeThunk[T, Never, F, False](function^))


def delay[T: Movable & Deinitable, X: Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingThunk[T, X]](var function: F
) -> _IODelay[E, _NativeThunk[T, X, F, True]] where _ErrorCompatible[E, X]:
    """Suspend a native function, retaining its exact compatible error type."""
    return delay[E](_NativeThunk[T, X, F, True](function^))


def run_io[P: ReaderAction](var program: P) -> IOContract[P].Out where IOContract[P].Compatible:
    """Consume an IO program synchronously with a fresh cancellation token.

    Parameters:
        P: A compatible IO recipe, including every captured origin.

    Args:
        program: The program, consumed once.

    Returns:
        Present Ok for success, present Err for accumulated exact failures, or
        absence for cancellation. No native callback error escapes this boundary.
    """
    return run_io(program^, CancellationToken())


def run_io[P: ReaderAction](var program: P, token: CancellationToken) -> IOContract[P].Out where IOContract[P].Compatible:
    """Run with a shared cancellation token supplied by the caller.

    The token remains reusable and is never reset. An already-canceled token
    skips the unopened program, including any unentered finalizer scopes.

    Parameters:
        P: A compatible concrete IO recipe.

    Args:
        program: The program, consumed once.
        token: The shared token, borrowed and copied into the run context.

    Returns:
        The exact IO outcome, with finalizer failures retained on cancellation.
    """
    var context = IOContext[IOContract[P].Error](token.copy(), False)
    return _run_io(program^, context)


@fieldwise_init
struct _IOCaptured[P: ReaderAction](ReaderAction):
    var program: Self.P
    comptime E = IOContract[Self.P].Error
    comptime Family = IO[Self.E]
    comptime Env = IOContext[Self.E]
    comptime Value = Self.P.Value
    comptime Out[o: ImmOrigin] = Outcome[Self.Value, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        comptime assert IOContract[Self.P].Compatible
        return _run_io(self.program^, env)


def capture_io[P: ReaderAction](var program: P) -> _IOCaptured[P] where IOContract[P].Compatible:
    """Capture native errors inside IO before applying stored-error recovery.

    Delay already captures its callback. A raising native callback passed to
    the general map or flat_map retains that operation's native error channel.
    Wrap the resulting program here before IO[E].or_else or Pipeline.recover
    to make that native error available as an EffectFailure. Cancellation stays
    separate and never invokes a stored-error recovery handler.

    Parameters:
        P: A compatible concrete IO program.

    Args:
        program: The program, consumed into a deferred capture boundary.

    Returns:
        The same success and IO error family, with no escaping native error.
    """
    return _IOCaptured(program^)


@fieldwise_init
struct _IOGuarantee[P: ReaderAction, Q: ReaderAction](ReaderAction):
    var program: Self.P
    var finalizer: Self.Q
    comptime E = IOContract[Self.P].Error
    comptime Family = IO[Self.E]
    comptime Env = IOContext[Self.E]
    comptime Value = Self.P.Value
    comptime Out[o: ImmOrigin] = Outcome[Self.Value, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        comptime assert IOContract[Self.P].Compatible and IOContract[Self.Q].Compatible
        comptime assert IOContract[Self.Q].Error == Self.E
        var result = _run_io(self.program^, env)
        var masked = env._mask()
        var cleanup = _run_io(self.finalizer^, rebind[IOContext[IOContract[Self.Q].Error]](masked))
        return _finish(result^, rebind_var[Outcome[Self.Q.Value, Self.E]](cleanup^))


def guarantee[P: ReaderAction, Q: ReaderAction](var program: P, var finalizer: Q
) -> _IOGuarantee[P, Q] where IOContract[P].Compatible and IOContract[Q].Compatible and IOContract[P].Error == IOContract[Q].Error:
    """Finalize an entered IO body exactly once, with cancellation masked.

    Finalization runs after success, failure or cancellation. Its success value
    is discarded. All errors remain ordered body first, then finalizer. Nested
    guarantees finalize from the inside out. Dropping an unopened recipe runs
    neither its body nor its finalizer.

    Parameters:
        P: The body program type.
        Q: A finalizer in the same selected IO error family.

    Args:
        program: The body, consumed into the new recipe.
        finalizer: The deferred finalizer, consumed; it must terminate to finish cancellation.

    Returns:
        A program with the body's success type and combined failure outcomes.
    """
    return _IOGuarantee(program^, finalizer^)


@fieldwise_init
struct _IOMasked[P: ReaderAction](ReaderAction):
    var program: Self.P
    comptime E = IOContract[Self.P].Error
    comptime Family = IO[Self.E]
    comptime Env = IOContext[Self.E]
    comptime Value = Self.P.Value
    comptime Out[o: ImmOrigin] = Outcome[Self.Value, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        comptime assert IOContract[Self.P].Compatible
        var masked = env._mask()
        return _run_io(self.program^, masked)


def uncancelable[P: ReaderAction](var program: P) -> _IOMasked[P] where IOContract[P].Compatible:
    """Mask cooperative cancellation during an entered program.

    Requests remain pending and are observed on returning to an unmasked run.
    Nested masks restore the enclosing context. This does not suppress errors.

    Parameters:
        P: A compatible IO program type.

    Args:
        program: The body, consumed without execution now.

    Returns:
        A deferred program with the same value and error family.
    """
    return _IOMasked(program^)


@fieldwise_init
struct _IOCancel[E: Movable & Deinitable](ReaderAction):
    comptime Family = IO[Self.E]
    comptime Env = IOContext[Self.E]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        env.request_cancel()
        var unit: NoneType = None
        return _settle(Optional(Result[NoneType, EffectFailure[Self.E]](Ok(unit))), env)


def canceled[E: Movable & Deinitable]() -> _IOCancel[E]:
    """Request cancellation when executed; masks defer its observation.

    Parameters:
        E: The selected IO error type.

    Returns:
        A deferred IO cancellation request with a unit success type while masked.
    """
    return _IOCancel[E]()


@fieldwise_init
struct _IOSleep[E: Movable & Deinitable](ReaderAction):
    var nanoseconds: Int
    comptime Family = IO[Self.E]
    comptime Env = IOContext[Self.E]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        var started = monotonic()
        var remaining = self.nanoseconds
        while remaining > 0:
            if env.canceled():
                return None
            sleep(min(Float64(remaining) / 1e9, 0.001))
            remaining = self.nanoseconds - (monotonic() - started)
        var unit: NoneType = None
        return _settle(Optional(Result[NoneType, EffectFailure[Self.E]](Ok(unit))), env)


def sleep_io[E: Movable & Deinitable](seconds: Float64) raises -> _IOSleep[E]:
    """Describe a synchronous, cooperatively cancelable wait.

    Uses the monotonic clock and sleeps in intervals of at most one millisecond.
    Actual scheduling and cancellation latency depend on the operating system.

    Parameters:
        E: The selected IO error family.

    Args:
        seconds: A finite, nonnegative duration no greater than one billion seconds.

    Returns:
        An unopened IO wait; zero duration is still a cancellation checkpoint.

    Raises:
        Error at construction for an invalid duration, before constructing a program.
    """
    if not isfinite(seconds) or seconds < 0 or seconds > 1e9:
        raise Error("sleep_io requires a finite duration between zero and one billion seconds")
    return _IOSleep[E](Int(seconds * 1e9))


@fieldwise_init
struct _IOResource[O: _OpenScope, F: BorrowCallContract & Movable & Deinitable](ReaderAction):
    var scope: Resource[Self.O]
    var function: Self.F
    comptime E = Self.O.Release.Error
    comptime Family = IO[Self.E]
    comptime Env = IOContext[Self.E]
    comptime Value = Self.F.Result
    comptime Out[o: ImmOrigin] = Outcome[Self.Value, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        comptime assert Self.F.Payload == Self.O.Release.Value and _ErrorCompatible[Self.E, Self.F.Failure] and _OnceBorrowAvailable[Self.F]
        if env.canceled():
            return None
        return _settle(Optional(self.scope^.use(self.function^)), env)


def use_resource[O: _OpenScope, F: BorrowCallContract & Movable & Deinitable](var scope: Resource[O], var function: F
) -> _IOResource[O, F] where F.Payload == O.Release.Value and _ErrorCompatible[O.Release.Error, F.Failure] and _OnceBorrowAvailable[F]:
    """Defer an entire synchronous native resource scope into its IO error family.

    Cancellation is observed before entry and after release. Native acquisition,
    use and release are synchronous and cannot be interrupted midway. This keeps
    release registered until it runs and preserves all native scope failures.

    Parameters:
        O: The concrete resource recipe.
        F: A borrowing native-use callback expressed through library contracts.

    Args:
        scope: The unopened scope, consumed into the IO recipe.
        function: The native use callback, consumed without executing now.

    Returns:
        An IO program yielding F.Result, with the scope's exact error family.
    """
    return _IOResource(scope^, function^)


def use_resource[O: _OpenScope, P: AnyType, V: Movable & Deinitable, //, F: _Borrowing[P, V]](var scope: Resource[O], var function: F
) -> _IOResource[O, _NativeBorrow[P, V, Never, F, False]] where P == O.Release.Value:
    """Adapt a native borrowing use callback into a deferred resource scope."""
    return use_resource(scope^, _NativeBorrow[P, V, Never, F, False](function^))


def use_resource[O: _OpenScope, P: AnyType, V: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingBorrowing[P, V, X]](var scope: Resource[O], var function: F
) -> _IOResource[O, _NativeBorrow[P, V, X, F, True]] where P == O.Release.Value and _ErrorCompatible[O.Release.Error, X]:
    """Adapt a native use callback with the scope's exact error type."""
    return use_resource(scope^, _NativeBorrow[P, V, X, F, True](function^))
