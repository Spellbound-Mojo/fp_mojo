"""Resumable coordination using canonical Ref transitions and Permit owners."""
from std.collections import Deque
from std.builtin.rebind import rebind_var
from std.os import abort
from fp.data import Result, Ok
from fp.effects import IOContext, Outcome, EffectFailure, ExitCase, Permit
from fp.effects.coordination import Deferred as _Deferred, Queue as _Queue, Semaphore as _Semaphore
from fp.effects.coordination import _RefAction, _RefModify, _RefInspect, _Complete, _Copy, _Size, _TryTake, _TryOffer, _Reserve
from fp.effects.outcomes import _failure_as
from fp._internal.cells import _try_lock
from fp.callables import OnceUnary
from .kernel import Machine, Step, Wait
from .family import Machine as _ApplicationMachine, Async
from .composition import pure
from .scopes import Scope, CleanupMachine, _ProgramUse
from .engine import IO


def _attempt[P: _RefAction](mut action: Optional[P], context: IOContext[P.SelectedError], notify: Bool) -> Step[P.Value, P.SelectedError]:
    if context.canceled():
        return .ready(None)
    var locked = _try_lock(action.value()._guard_cell())
    if not locked:
        # Guard contention yields one bounded attempt, never a blocking wait.
        return .pending(Wait())
    return .ready(action.take()._locked(locked.take(), context, notify))


struct _Once[P: _RefAction](_ApplicationMachine):
    comptime Family = Async[Self.Error]
    comptime Value = Self.P.Value
    comptime Error = Self.P.SelectedError
    var action: Optional[Self.P]
    var completed: Bool

    def __init__(out self, var action: Self.P):
        self.action = Optional(action^)
        self.completed = False

    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        if self.completed:
            abort("coordination operation polled after completion")
        var step = _attempt(self.action, context, True)
        self.completed = Bool(step._completed)
        return step^


struct _Await[A: Movable & Deinitable, P: _RefAction & Copyable](_ApplicationMachine):
    comptime Family = Async[Self.Error]
    comptime Value = Self.A
    comptime Error = Self.P.SelectedError
    var template: Self.P
    var action: Optional[Self.P]
    var notify_success: Bool
    var completed: Bool

    def __init__(out self, var action: Self.P, notify_success: Bool):
        comptime assert Self.P.Value == Optional[Self.A]
        self.action = Optional(action.copy())
        self.template = action^
        self.notify_success = notify_success
        self.completed = False

    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.A, Self.Error]:
        comptime assert Self.P.Value == Optional[Self.A]
        if self.completed:
            abort("coordination wait polled after completion")
        var changed = self.template._changes()
        # Observe the event before the state: registration rechecks revision.
        var revision = changed.revision()
        var step = _attempt(self.action, context, False)
        if not step._completed:
            return .pending(step^._waiting())
        var outcome = rebind_var[Outcome[Optional[Self.A], Self.Error]](step^._outcome())
        if not outcome or outcome.value().is_err():
            self.completed = True
            if self.notify_success:
                changed.notify()
            return .ready(_failure_as[Self.A](outcome^))
        var value = outcome.take()._take_ok()
        if value:
            self.completed = True
            if self.notify_success:
                changed.notify()
            return .ready(Optional(Result[Self.A, EffectFailure[Self.Error]](Ok(value.take()))))
        self.action = Optional(self.template.copy())
        # An unavailable value is not a state change. Notifying here would let
        # empty-queue waiters keep one another runnable indefinitely.
        var wait = Wait.changed(changed, revision)
        wait._interruptible = not context._masked
        return .pending(wait^)


struct Deferred[T: Copyable & Deinitable](Copyable):
    """Shared single-assignment value; waiting readers receive owned copies.

    Parameters:
        T: The stored value, copied for successful reads.
    """
    var _source: _Deferred[Self.T]

    def __init__(out self):
        self._source = _Deferred[Self.T]()

    def complete[E: Movable & Deinitable](self, var value: Self.T) -> IO[Bool, E]:
        """Attempt single assignment when the recipe executes.

        Parameters:
            E: The selected domain error of the returned recipe.

        Args:
            value: The owned value, consumed into the unopened recipe.

        Returns:
            An IO yielding whether this assignment won; later assignments leave the stored value intact."""
        return IO[Bool, E]._lifted(_Once(self._source.complete[E](value^)))

    def try_get[E: Movable & Deinitable](self) -> IO[Optional[Self.T], E]:
        """Read the current assignment without waiting.

        Parameters:
            E: The selected domain error of the returned recipe.

        Returns:
            An IO yielding an owned optional copy of the value."""
        return IO[Optional[Self.T], E]._lifted(_Once(self._source.try_get[E]()))

    def get[E: Movable & Deinitable](self) -> IO[Self.T, E]:
        """Wait cooperatively for assignment, unless canceled.

        Parameters:
            E: The selected domain error of the returned recipe.

        Returns:
            An IO yielding an owned copy after assignment."""
        return IO[Self.T, E]._lifted(_Await[Self.T, _RefInspect[Optional[Self.T], E, _Copy[Optional[Self.T]]]](self._source.get[E]()._into_attempt(), False))


struct _Offer[T: Movable & Deinitable, E: Movable & Deinitable](_ApplicationMachine):
    comptime Family = Async[Self.Error]
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
