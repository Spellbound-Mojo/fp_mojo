"""The current-thread executor: one worker, the thread that drives the root.

Every fiber is a task (`_TaskHeader` in `waking.mojo`) with its own wake
registry, whose hook queues the task when something in it becomes ready. One
root poll is one executor turn: it runs queued tasks in FIFO order, each at
most once, while the root's transition budget lasts. A task requeued during the
turn waits for the next one, so the order stays deterministic. The root program
is a task too; its driver polls it when its turn comes.

The same tasks can later run on a work-stealing pool: a queue entry is the
right to run a task, and a task's state is reached only through it.
"""
from std.memory import ArcPointer
from fp._internal.waking import _Runtime, _Scheduler, _TaskHeader


struct _Executor(Movable):
    """The scheduling state of one root on the current-thread profile."""
    var scheduler: ArcPointer[_Scheduler]
    var root: ArcPointer[_TaskHeader]
    var turn: UInt64
    # A task popped in the turn in which it already ran: first in the next turn.
    var carry: Optional[ArcPointer[_TaskHeader]]

    def __init__(out self, runtime: _Runtime):
        self.scheduler = runtime.scheduler()
        var root = _TaskHeader.for_root()
        root.registry = Optional(runtime.copy())
        self.root = ArcPointer(root^)
        self.turn = 0
        self.carry = None

    def ready(self) -> Bool:
        """Whether a task is queued."""
        return Bool(self.carry) or self.scheduler[].queued() > 0

    def begin_turn(mut self):
        self.turn += 1

    def next(mut self) -> Optional[ArcPointer[_TaskHeader]]:
        """The next task to run in this turn, marked running; none ends the turn."""
        var task: Optional[ArcPointer[_TaskHeader]]
        if self.carry:
            task = self.carry.take()
        else:
            task = self.scheduler[].pop()
        if not task:
            return None
        if task.value()[].turn == self.turn:
            self.carry = task^
            return None
        task.value()[].turn = self.turn
        task.value()[].begin_run()
        return task^

    @staticmethod
    def run(task: ArcPointer[_TaskHeader]):
        """Run a fiber task once, then park, requeue, or retire it."""
        var run = task[].run
        var done = run(task[].body)
        _Executor.settle(task, done)

    @staticmethod
    def settle(task: ArcPointer[_TaskHeader], done: Bool):
        if done:
            task[].registry.value().detach()
            task[].finish()
        else:
            task[].registry.value().park(task)

    def fiber_slots(self) -> Int:
        return self.scheduler[].fiber_slots()
