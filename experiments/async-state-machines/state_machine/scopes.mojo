"""Scope-owned resources lent for each poll; stored state never borrows its owner."""
from std.builtin.rebind import rebind_var
from fp.effects import IOContext, Outcome, ExitCase
from fp.effects._io_core import _settle
from fp.effects.outcomes import _ExitState, _finish
from fp.effects.resources import _scope_failure
from std.os import abort
from .kernel import Machine, Step, Wait


trait ScopedMachine(Movable, Deinitable):
    comptime Input: Movable & Deinitable
    comptime Value: Movable & Deinitable
    comptime Error: Movable & Deinitable
    def poll[p: ImmOrigin](mut self, ref[p] value: Self.Input, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        ...


trait CleanupMachine(Movable, Deinitable):
    comptime Input: Movable & Deinitable
    comptime Error: Movable & Deinitable
    def poll[p: ImmOrigin](mut self, ref[p] value: Self.Input, exit: ExitCase[Self.Error],
        context: IOContext[Self.Error]
    ) -> Step[NoneType, Self.Error]:
        ...


@fieldwise_init
struct _ProgramUse[P: Machine, T: Movable & Deinitable](ScopedMachine):
    """Adapt an owned program at the scoped native invocation boundary."""
    var program: Self.P
    comptime Input = Self.T
    comptime Value = Self.P.Value
    comptime Error = Self.P.Error
    def poll[o: ImmOrigin](mut self, ref[o] value: Self.T, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        return self.program.poll(context)


struct Scope[A: Machine, U: ScopedMachine, C: CleanupMachine](Machine):
    var acquire: Optional[Self.A]
    var use: Self.U
    var cleanup: Self.C
    var resource: Optional[Self.A.Value]
    var completed: Optional[_ExitState[Self.U.Value, Self.A.Error]]
    var masked: Optional[IOContext[Self.A.Error]]
    var phase: Int
    var use_started: Bool
    comptime Value = Self.U.Value
    comptime Error = Self.A.Error

    def __init__(out self, var acquire: Self.A, var use: Self.U, var cleanup: Self.C):
        comptime assert Self.A.Value == Self.U.Input and Self.A.Value == Self.C.Input
        comptime assert Self.A.Error == Self.U.Error and Self.A.Error == Self.C.Error
        self.acquire = Optional(acquire^)
        self.use = use^
        self.cleanup = cleanup^
        self.resource = None
        self.completed = None
        self.masked = None
        self.phase = 0
        self.use_started = False

    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        comptime assert Self.A.Value == Self.U.Input and Self.A.Value == Self.C.Input
        comptime assert Self.A.Error == Self.U.Error and Self.A.Error == Self.C.Error
        if self.phase == 0:
            if context.canceled():
                self.phase = 4
                return Step[Self.Value, Self.Error].ready(None)
            self.masked = Optional(context._mask())
            self.phase = 1
        if self.phase == 1:
            var step = self.acquire.value().poll(self.masked.value())
            if not step.completed:
                step.wait.interruptible = False
                return Step[Self.Value, Self.Error].pending(step^.waiting())
            var acquired = step^.outcome()
            self.acquire = None
            if not acquired or acquired.value().is_err():
                self.phase = 4
                return Step[Self.Value, Self.Error].ready(_scope_failure[Self.Value](acquired^))
            self.resource = Optional(acquired.take()._take_ok())
            self.masked = None
            self.phase = 2
            return Step[Self.Value, Self.Error].pending(Wait())
        if self.phase == 2:
            # The borrow ends when poll returns, before the driver sees Pending.
            var step: Step[Self.Value, Self.Error]
            if not self.use_started and context.canceled():
                step = Step[Self.Value, Self.Error].ready(None)
            else:
                self.use_started = True
                step = rebind_var[Step[Self.Value, Self.Error]](self.use.poll(rebind[Self.U.Input](self.resource.value()), rebind[IOContext[Self.U.Error]](context)))
            if not step.completed:
                return step^
            self.completed = Optional(_ExitState(_settle(step^.outcome(), context)))
            self.masked = Optional(context._mask())
            self.phase = 3
            return Step[Self.Value, Self.Error].pending(Wait())
        if self.phase == 3:
            var step = rebind_var[Step[NoneType, Self.Error]](self.cleanup.poll(rebind[Self.C.Input](self.resource.value()), rebind[ExitCase[Self.C.Error]](self.completed.value().exit), rebind[IOContext[Self.C.Error]](self.masked.value())))
            if not step.completed:
                step.wait.interruptible = False
                return Step[Self.Value, Self.Error].pending(step^.waiting())
            var outcome = _finish(self.completed.take().outcome(), step^.outcome())
            self.resource = None
            self.masked = None
            self.phase = 4
            return Step[Self.Value, Self.Error].ready(_settle(outcome^, context))
        abort("scope polled after completion")
