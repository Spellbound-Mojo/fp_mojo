"""One guarded coordination attempt, and waiting for a coordination owner to change.

These private machines run the canonical Ref transitions of the shared
coordination owners in `fp.effects.coordination`. They sit below the IO engine
so both the handles beside IO (Ref, Deferred) and the coordination module
(Queue, Semaphore) use one implementation.
"""
from std.builtin.rebind import rebind_var
from std.os import abort
from fp.data import Result, Ok
from fp.effects import IOContext, Outcome, EffectFailure
from fp.effects.coordination import _RefAction
from fp.effects.outcomes import _failure_as
from fp._internal.cells import _try_lock
from .kernel import Machine, Step, Wait


def _attempt[P: _RefAction](mut action: Optional[P], context: IOContext[P.SelectedError], notify: Bool) -> Step[P.Value, P.SelectedError]:
    if context.canceled():
        return .ready(None)
    var locked = _try_lock(action.value()._guard_cell())
    if not locked:
        # Guard contention yields one bounded attempt, never a blocking wait.
        return .pending(Wait())
    return .ready(action.take()._locked(locked.take(), context, notify))


struct _Once[P: _RefAction](Machine):
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


struct _Await[A: Movable & Deinitable, P: _RefAction & Copyable](Machine):
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
