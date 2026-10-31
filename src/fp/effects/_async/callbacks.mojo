"""Typed single-completion registration with owned, suspending withdrawal."""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.builtin.rebind import downcast, rebind_var
from std.os import abort
from fp.callables.protocols import UnaryContract
from fp.callables.invoke import _OnceUnaryAvailable
from fp.callables._binding import _OwnedUnary
from fp._internal.errors import _ErrorCompatible
from fp.effects import IOContext, CancellationToken, Outcome
from fp._internal.oneshot import _OneShot, _CLAIMED, _CLOSED
from fp.effects.outcomes import _discard, _capture, _finish, _failure_as, _ExitState
from fp.effects._io_core import _settle
from .kernel import Machine, Step, Wait, Signal, _Slot, _tick


# Both native no-result signatures and explicit unit values are admissible.
# Registration discards its unit through the canonical result owner.
comptime _CallbackUnit[T: Movable & Deinitable] = T == NoneType or T == type_of(None)


trait _CompletionType:
    comptime Value: Movable & Deinitable
    comptime Error: Movable & Deinitable


struct Completion[T: Movable & Deinitable, E: Movable & Deinitable](Copyable, _CompletionType):
    """Copies share one terminal decision; the cell survives late callbacks.

    Copies may be moved to, used on, and destroyed on another thread, and
    `complete` is safe from any thread. The decision is a lock-free one-shot
    slot (`fp._internal.oneshot`): the first `complete` claims it, writes the
    outcome and publishes it with release ordering, and the registration takes
    it with acquire ordering, so writes made before `complete` are visible to
    the continuation receiving the value. Mojo has no Send or Sync proof: the
    outcome's value and error may move to, and be destroyed on, either thread,
    so their destructors must not hold locks the other thread needs.

    Parameters:
        T: The exact owned completion value, including external origins.
        E: The exact domain error of the registration and withdrawal scope.
    """
    comptime Value = Self.T
    comptime Error = Self.E
    var _shot: ArcPointer[_OneShot[Outcome[Self.T, Self.E]]]
    var _signal: Signal

    def __init__(out self):
        self._shot = ArcPointer(_OneShot[Outcome[Self.T, Self.E]]())
        self._signal = Signal()

    def complete(self, var outcome: Outcome[Self.T, Self.E]) -> Bool:
        """Offer an owned terminal outcome once through the cooperative host boundary.

        Args:
            outcome: The success, complete ordered failure, or cancellation-only value.

        Returns:
            True if the outcome was admitted; exactly one outcome is. Admission
            does not promise use: if withdrawal races it, the admitted outcome
            is dropped on the polling thread. False after an earlier
            completion, after withdrawal began, or after the root finished;
            the rejected outcome is then destroyed on the calling thread,
            holding nothing another thread waits for."""
        if not self._shot[].try_claim():
            # Rejected: destroyed here, with nothing locked, before returning.
            _ = outcome^
            return False
        # The registration never releases its right, so publication keeps nothing.
        _ = self._shot[].publish(outcome^)
        self._signal.notify()
        return True

    def _select(self, cancel: Bool) -> Optional[Outcome[Self.T, Self.E]]:
        """The admitted outcome, a cancellation if `cancel` closes first, or none yet.

        None while nothing is admitted and `cancel` is false, and while an
        admitted outcome is still being written; its writer notifies the signal.
        """
        if cancel:
            var before = self._shot[].close()
            if not before & _CLAIMED:
                if before & _CLOSED:
                    return None
                return Optional(Outcome[Self.T, Self.E]())
        return self._shot[].take()

    def _registration_failed(self, var failed: Outcome[NoneType, Self.E]) -> Outcome[Self.T, Self.E]:
        _ = self._shot[].close()
        # A completion that claimed the slot first is admitted: wait for its
        # write, which is a move on the completing thread, then use it.
        self._shot[].wait_published()
        var selected = self._shot[].take()
        self._signal.notify()
        if selected:
            return _finish(selected.take(), failed^)
        return _failure_as[Self.T](failed^)


struct Callback[F: UnaryContract & Movable & Deinitable, C: Machine](Machine):
    comptime Contract = downcast[Self.F.Arg, _CompletionType]
    comptime Value = Self.Contract.Value
    comptime Error = Self.Contract.Error
    var register: Optional[Self.F]
    var completion: Completion[Self.Value, Self.Error]
    var cleanup: _Slot[Self.C, Self.C.Value, Self.C.Error]
    var completed: Optional[_ExitState[Self.Value, Self.Error]]
    var masked: Optional[IOContext[Self.Error]]
    var phase: Int
    # The scheduler's count of live registrations while this one is live, so
    # the root can tell waiting for an external event from waiting for nothing.
    var counted: Optional[ArcPointer[Atomic[Int]]]

    def __init__(out self, var register: Self.F, var cleanup: Self.C):
        comptime assert Self.F.Arg == Completion[Self.Value, Self.Error] and _CallbackUnit[Self.F.Out]
        comptime assert _OnceUnaryAvailable[Self.F] and _ErrorCompatible[Self.Error, Self.F.Error]
        comptime assert _CallbackUnit[Self.C.Value] and Self.C.Error == Self.Error
        self.register = Optional(register^)
        self.completion = Completion[Self.Value, Self.Error]()
        self.cleanup = _Slot[Self.C, Self.C.Value, Self.C.Error](cleanup^)
        self.completed = None
        self.masked = None
        self.phase = 0
        self.counted = None

    def __deinit__(deinit self):
        self._uncount()

    def _uncount(mut self):
        if self.counted:
            # Release: the registration's last accesses happen before a reader
            # that acquires the lower count. The drop may run on any thread.
            _ = self.counted.value()[].fetch_sub[ordering=Ordering.RELEASE](1)
            self.counted = None

    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        comptime assert Self.F.Arg == Completion[Self.Value, Self.Error] and _CallbackUnit[Self.F.Out]
        comptime assert _OnceUnaryAvailable[Self.F] and _ErrorCompatible[Self.Error, Self.F.Error]
        comptime assert _CallbackUnit[Self.C.Value] and Self.C.Error == Self.Error
        match self.phase:
            case 0:
                if context.canceled():
                    self.phase = 3
                    return .ready(None)
                var registered = _capture[Self.Error](_OwnedUnary(self.register.take(), rebind_var[Self.F.Arg](self.completion.copy())))
                if registered.is_err():
                    self.begin_cleanup(self.completion._registration_failed(Optional(_discard(registered^))), context)
                else:
                    self.phase = 1
                    if context._budget:
                        var counter = context._budget.value()[].registrations.copy()
                        # Release: the registration is published before a
                        # reader that acquires the higher count.
                        _ = counter[].fetch_add[ordering=Ordering.RELEASE](1)
                        self.counted = Optional(counter^)
                return .pending(Wait())
            case 1:
                var revision = self.completion._signal.revision()
                var selected = self.completion._select(context.canceled())
                if selected:
                    self._uncount()
                    self.begin_cleanup(selected.take(), context)
                    return .pending(Wait())
                var wait = Wait.changed(self.completion._signal, revision)
                wait._interruptible = not context._masked
                return .pending(wait^)
            case 2:
                _ = _tick(self.cleanup, rebind[IOContext[Self.C.Error]](self.masked.value()))
                if not self.cleanup.done():
                    var wait = self.cleanup.waiting()
                    wait._interruptible = False
                    return .pending(wait^)
                var cleanup = rebind_var[Outcome[Self.C.Value, Self.Error]](self.cleanup.take_outcome())
                var outcome = _finish(self.completed.take().outcome(), cleanup^)
                self.phase = 3
                return .ready(_settle(outcome^, context))
            case _:
                abort("callback polled after completion")

    def begin_cleanup(mut self, var outcome: Outcome[Self.Value, Self.Error], context: IOContext[Self.Error]):
        self.completed = Optional(_ExitState(_settle(outcome^, context)))
        self.masked = Optional(context._mask())
        self.phase = 2


def callback[F: UnaryContract & Movable & Deinitable, C: Machine](var register: F, var cleanup: C) -> Callback[F, C]:
    return Callback(register^, cleanup^)
