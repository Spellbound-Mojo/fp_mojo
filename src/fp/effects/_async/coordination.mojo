"""Queue and Semaphore over canonical Ref transitions and Permit owners.

The async Ref and Deferred live beside IO in the engine, because Async names
them as its Concurrent handles.
"""
from std.collections import Deque
from std.os import abort
from fp.data import Result, Ok
from fp.effects import IOContext, EffectFailure, ExitCase, Permit
from fp.effects.coordination import Queue as _Queue, Semaphore as _Semaphore
from fp.effects.coordination import _RefModify, _TryTake, _TryOffer, _Reserve
from fp.effects.outcomes import _failure_as
from fp.callables import OnceUnary
from .kernel import Machine, Step, Wait
from .attempts import _attempt, _Once, _Await
from .composition import pure
from .scopes import Scope, CleanupMachine, _ProgramUse
from .engine import IO


struct _Offer[T: Movable & Deinitable, E: Movable & Deinitable](Machine):
    comptime Value = NoneType
    comptime Error = Self.E
    comptime Attempt = _RefModify[Deque[Self.T], Optional[Self.T], Self.E, _TryOffer[Self.T]]
    var queue: _Queue[Self.T]
    var action: Optional[Self.Attempt]
    var completed: Bool

    def __init__(out self, queue: _Queue[Self.T], var value: Self.T):
        self.queue = queue.copy()
        self.action = Optional(queue.try_offer[Self.E](value^))
        self.completed = False

    def poll(mut self, context: IOContext[Self.E]) -> Step[NoneType, Self.E]:
        if self.completed:
            abort("queue offer polled after completion")
        var changed = self.queue._state._changed.copy()
        var revision = changed.revision()
        var step = _attempt(self.action, context, False)
        if not step._completed:
            return .pending(step^._waiting())
        var outcome = step^._outcome()
        if not outcome or outcome.value().is_err():
            self.completed = True
            changed.notify()
            return .ready(_failure_as[NoneType](outcome^))
        var rejected = outcome.take()._take_ok()
        if rejected:
            self.action = Optional(self.queue.try_offer[Self.E](rejected.take()))
            var wait = Wait.changed(changed, revision)
            wait._interruptible = not context._masked
            return .pending(wait^)
        self.completed = True
        changed.notify()
        var unit: NoneType = None
        return .ready(Optional(Result[NoneType, EffectFailure[Self.E]](Ok(unit))))


struct Queue[T: Movable & Deinitable](Copyable):
    """Bounded FIFO of owned values; waiting offers retain rejected inputs.

    Parameters:
        T: The exact owned element type, including external origins.
    """
    var _source: _Queue[Self.T]

    def __init__(out self, capacity: Int) raises:
        self._source = _Queue[Self.T](capacity)

    def size[E: Movable & Deinitable](self) -> IO[Int, E]:
        """Read the current number of queued values.

        Parameters:
            E: The selected domain error of the returned recipe.

        Returns:
            An IO yielding the observed queue size."""
        return IO[Int, E]._lifted(_Once(self._source.size[E]()))

    def try_offer[E: Movable & Deinitable](self, var value: Self.T) -> IO[Optional[Self.T], E]:
        """Attempt to enqueue one owned value without waiting.

        Parameters:
            E: The selected domain error of the returned recipe.

        Args:
            value: The owned value, consumed into the unopened recipe.

        Returns:
            An IO yielding None on admission or the original value when full."""
        return IO[Optional[Self.T], E]._lifted(_Once(self._source.try_offer[E](value^)))

    def offer[E: Movable & Deinitable](self, var value: Self.T) -> IO[NoneType, E]:
        """Wait cooperatively to enqueue one owned value.

        Parameters:
            E: The selected domain error of the returned recipe.

        Args:
            value: The owned value, consumed into the unopened recipe.

        Returns:
            An IO yielding NoneType after admission; cancellation destroys a retained input."""
        return IO[NoneType, E]._lifted(_Offer[Self.T, E](self._source, value^))

    def try_take[E: Movable & Deinitable](self) -> IO[Optional[Self.T], E]:
        """Attempt to remove the oldest queued value without waiting.

        Parameters:
            E: The selected domain error of the returned recipe.

        Returns:
            An IO yielding the owned value if available."""
        return IO[Optional[Self.T], E]._lifted(_Once(self._source.try_take[E]()))

    def take[E: Movable & Deinitable](self) -> IO[Self.T, E]:
        """Wait cooperatively for the oldest queued value.

        Parameters:
            E: The selected domain error of the returned recipe.

        Returns:
            An IO transferring the removed value; cancellation remains observable."""
        return IO[Self.T, E]._lifted(_Await[Self.T, _RefModify[Deque[Self.T], Optional[Self.T], E, _TryTake[Self.T]]](self._source.take[E]()._into_attempt(), True))


comptime _PermitUse[P: Machine] = _ProgramUse[P, Permit]


@fieldwise_init
struct _PermitRelease[E: Movable & Deinitable](CleanupMachine):
    comptime Input = Permit
    comptime Error = Self.E
    def poll[o: ImmOrigin](mut self, ref[o] permit: Permit, exit: ExitCase[Self.E], context: IOContext[Self.E]) -> Step[NoneType, Self.E]:
        var unit: NoneType = None
        return .ready(Optional(Result[NoneType, EffectFailure[Self.E]](Ok(unit))))


@fieldwise_init
struct _WithPermit[P: Machine](OnceUnary):
    var program: Self.P
    comptime Arg = Permit
    comptime Out = IO[Self.P.Value, Self.P.Error]
    def call_once(deinit self, var permit: Permit) -> Self.Out:
        # The canonical scope retains the permit until the body and release finish.
        return Self.Out._lifted(Scope(pure[Self.P.Error](permit^), _PermitUse(self.program^), _PermitRelease[Self.P.Error]()))


struct Semaphore(Copyable):
    """Cancelable acquisition with canonical owned permits and scoped use."""
    var _source: _Semaphore

    def __init__(out self, permits: Int) raises:
        self._source = _Semaphore(permits)

    def available[E: Movable & Deinitable](self) -> IO[Int, E]:
        """Read the current number of available permits.

        Parameters:
            E: The selected domain error of the returned recipe.

        Returns:
            An IO yielding the observed permit count."""
        return IO[Int, E]._lifted(_Once(self._source.available[E]()))

    def acquire[E: Movable & Deinitable](self) -> IO[Permit, E]:
        """Wait cooperatively for an owned canonical permit.

        Parameters:
            E: The selected domain error of the returned recipe.

        Returns:
            An IO transferring one permit; cancellation before admission consumes none."""
        return IO[Permit, E]._lifted(_Await[Permit, _RefModify[Int, Optional[Permit], E, _Reserve]](self._source.acquire[E]()._into_attempt(), False))

    def with_permit[P: Machine](self, var program: P) -> IO[P.Value, P.Error]:
        """Acquire cancelably, run an owned body, then release through the canonical scope.

        Parameters:
            P: The body: an IO, or a machine that owns its state.

        Args:
            program: The unopened body, consumed once.

        Returns:
            An IO retaining the permit until the body and cleanup finish."""
        # Acquire cancelably, then transfer the owned permit into a Scope.
        return self.acquire[P.Error]()._bind(_WithPermit(program^))
