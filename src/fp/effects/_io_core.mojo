"""Concrete IO recipes over the existing Reader, Result and Optional families."""
from std.atomic import Atomic
from std.memory import ArcPointer
from std.time import monotonic, sleep
from std.math import isfinite, min
from std.builtin.rebind import downcast, rebind_var
from fp.algebra.instances import OptionalFamily
from fp.callables.protocols import OnceThunk, ThunkContract, BorrowCallContract, UnaryContract
from fp.callables.invoke import _OnceThunkAvailable
from fp.callables._receiver import _OnceBorrowAvailable
from fp.callables._binding import _OwnedThunk
from fp.callables.native import _NativeThunk, _Thunk, _RaisingThunk, _NativeBorrow, _Borrowing, _RaisingBorrowing
from fp.data import Result, Ok, Err
from fp._internal.errors import _ErrorCompatible
from .protocols import ReaderAction, Defer, Cancel
from .reader import ReaderT, _LocalIndependent
from .layers import ResultT
from .outcomes import EffectFailure, Outcome, _capture, _finish
from fp._internal.time import Instant
from fp._internal.waking import _Event, _Clock, _Runtime, _Ticket


struct CancellationToken(Copyable):
    """A shared atomic cancellation request; cancellation is cooperative.

    Copies share one flag. Requesting cancellation never kills a thread or
    interrupts native code. IO observes it at its documented checkpoints.
    """
    var _flag: ArcPointer[Atomic[UInt8]]
    var _event: _Event
    def __init__(out self):
        self._flag = ArcPointer(Atomic(UInt8(0)))
        self._event = _Event()

    def cancel(self):
        """Request cancellation for every computation using this token."""
        var expected = UInt8(0)
        if self._flag[].compare_exchange(expected, UInt8(1)):
            self._event.notify()

    def requested(self) -> Bool:
        """Read whether cancellation was requested, without resetting it.

        Returns:
            True after any copy receives cancel.
        """
        return self._flag[].load() != 0


trait _IOContextType:
    comptime NativeError: Movable & Deinitable


comptime _Reporter = def(String) thin
"""A host callback receiving one formatted line per unhandled fiber failure."""


struct _Budget(Movable):
    """Interpreter transitions shared by every run loop under one root.

    The root refills the slice before each root poll; run loops draw from it and
    yield when it is spent. It also carries the root's fiber failure reporting.
    The state is confined to the root's polling thread.
    """
    var remaining: Int
    var consumed: Int
    var yield_threshold: Int
    var check_threshold: Int
    var report: Bool
    var reporter: _Reporter

    def __init__(out self, yield_threshold: Int, check_threshold: Int, report: Bool, reporter: _Reporter):
        self.remaining = yield_threshold
        self.consumed = 0
        self.yield_threshold = yield_threshold
        self.check_threshold = check_threshold
        self.report = report
        self.reporter = reporter

    def refill(mut self):
        self.remaining = self.yield_threshold


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

    var _region: Optional[ArcPointer[Int]]
    var _clock: _Clock
    var _runtime: Optional[_Runtime]
    var _parent: Optional[_Ticket]
    var _budget: Optional[ArcPointer[_Budget]]
    # The running fiber's identity, or 0 outside fibers; for self-join checks.
    var _fiber: Int

    def __init__(out self, var _token: CancellationToken, _masked: Bool):
        self._token = _token^
        self._masked = _masked
        self._region = Optional(ArcPointer(0)) if _masked else None
        self._clock = _Clock()
        self._runtime = None
        self._parent = None
        self._budget = None
        self._fiber = 0

    def canceled(self) -> Bool:
        """Check cancellation at this context's current masking level.

        Returns:
            True only when cancellation is both requested and unmasked.
        """
        return not self._masked and self._token.requested()

    def request_cancel(self):
        """Request cancellation, even if observation is currently masked."""
        self._token.cancel()

    def now(self) -> Instant:
        """Read opaque monotonic time from the inherited execution clock.

        Returns:
            An Instant in this clock origin, suitable for async Wait.until after
            adding a checked Duration. This does not read wall-clock time.
        """
        return self._clock.now()

    def _mask(self) -> Self:
        var masked = Self(self._token.copy(), True)
        masked._inherit(self)
        return masked^

    def _inherit(mut self, parent: Self):
        self._clock = parent._clock.copy()
        self._runtime = parent._runtime.copy()
        self._parent = parent._parent.copy()
        self._budget = parent._budget.copy()
        self._fiber = parent._fiber


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


def _settle[T: Movable & Deinitable, E: Movable & Deinitable](var value: Outcome[T, E], context: IOContext[E], preserve_success: Bool = False) -> Outcome[T, E]:
    if not value:
        return None
    var result = value.take()
    if result.is_err():
        var failure = result^._take_err()
        failure.canceled = failure.canceled or context.canceled()
        return Optional(Result[T, EffectFailure[E]](Err(failure^)))
    if not preserve_success and context.canceled():
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


@fieldwise_init
struct _IODefer[E: Movable & Deinitable, F: ThunkContract & Movable & Deinitable](ReaderAction):
    """Build an IO program when it is reached, then run it in the same context."""
    var factory: Self.F
    comptime Program = downcast[Self.F.Out, ReaderAction]
    comptime Family = IO[Self.E]
    comptime Value = Self.Program.Value
    comptime Env = IOContext[Self.E]
    comptime Out[o: ImmOrigin] = Outcome[Self.Value, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        if env.canceled():
            return None
        comptime assert _ErrorCompatible[Self.E, Self.F.Error] and conforms_to(Self.F.Out, ReaderAction)
        comptime assert IOContract[Self.Program].Compatible and IOContract[Self.Program].Error == Self.E
        var built = _capture[Self.E](_OwnedThunk(self.factory^))
        if built.is_err():
            return _settle(Optional(Result[Self.Value, EffectFailure[Self.E]](Err(built^._take_err()))), env)
        return rebind_var[Self.Out[o]](_run_io(rebind_var[Self.Program](built^._take_ok()), rebind[IOContext[IOContract[Self.Program].Error]](env)))


comptime _SyncDefers[E: Movable & Deinitable, F: ThunkContract & Movable & Deinitable] = (
    _ErrorCompatible[E, F.Error] and _OnceThunkAvailable[F] and IOContract[downcast[F.Out, ReaderAction]].Compatible
    and IOContract[downcast[F.Out, ReaderAction]].Error == E) if conforms_to(F.Out, ReaderAction) else False
"""Whether F builds a synchronous IO program with error E, raising E or nothing."""


struct DelayContract[F: ThunkContract & Movable & Deinitable, E: Movable & Deinitable]:
    """Name a delayed action in generic and origin-dependent factories.

    Parameters:
        F: The exact once-callable thunk type.
        E: The selected IO error family.
    """
    comptime Compatible = _ErrorCompatible[Self.E, Self.F.Error] and _OnceThunkAvailable[Self.F]
    """Whether this callback can be captured in the selected IO family."""
    comptime Out = _IODelay[Self.E, Self.F]
    """The concrete delayed action, retaining all callback origins."""


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


def delay[F: ThunkContract & Movable & Deinitable, //, I: Defer](var function: F) -> I.Delayed[F] where I.DelayCompatible[F]:
    """Run a function when the program reaches it, in any family with Defer.

    Parameters:
        F: An owned once-callable thunk the family admits.
        I: The capability dictionary, such as Async[E] or SyncIO[E].

    Args:
        function: The function, consumed.

    Returns:
        The family's carrier producing the function's value.
    """
    return I.delay(function^)


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
        return _settle(_run_io(self.program^, masked), env)


def restore[V: Movable & Deinitable, //, I: Cancel](poll: I.RegionPoll, var program: V) -> I.Restored[V] where I.RestoreCompatible[V]:
    """Run part of a masked region with the cancellation state outside it.

    Parameters:
        V: The program's carrier type.
        I: The capability dictionary, such as Async[E] or SyncIO[E].

    Args:
        poll: The region's poll, borrowed.
        program: The program, consumed.

    Returns:
        The family's restored carrier.
    """
    return I.restore(poll, program^)


def uncancelable[F: UnaryContract & Movable & Deinitable, //, I: Cancel](var body: F) -> I.Uncanceled[F] where I.UncancelableCompatible[F]:
    """Run a region masked in any family with Cancel; its Poll restores the outer state.

    Parameters:
        F: An owned once-callable from the family's Poll to its carrier.
        I: The capability dictionary, such as Async[E] or SyncIO[E].

    Args:
        body: The region's factory, consumed.

    Returns:
        The family's masked carrier.
    """
    return I.uncancelable(body^)


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


def canceled[I: Cancel]() -> I.Canceled:
    """Request cancellation of the running program, in any family with Cancel.

    Parameters:
        I: The capability dictionary, such as Async[E] or SyncIO[E].

    Returns:
        The family's unit carrier; a mask defers observing the request.
    """
    return I.canceled()


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


struct _IOMonotonic[E: Movable & Deinitable](ReaderAction, Defaultable):
    """Read the context's clock once, for the synchronous Timing provider."""
    comptime Family = IO[Self.E]
    comptime Env = IOContext[Self.E]
    comptime Value = Instant
    comptime Out[o: ImmOrigin] = Outcome[Instant, Self.E]

    def __init__(out self):
        pass

    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        return _settle(Optional(Result[Instant, EffectFailure[Self.E]](Ok(env.now()))), env)


def sleep_io[E: Movable & Deinitable](seconds: Float64) raises -> _IOSleep[E]:
    """Describe a synchronous, cooperatively cancelable wait.

    Uses the system monotonic clock, even when the context inherits a manual
    one, and blocks the thread in intervals of at most one millisecond. Inside
    an async IO through `IO.eval_io`, it blocks the cooperative host as well.
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


