"""The current-thread executor: one worker, the thread that drives the root.

Every fiber is a task (`_TaskHeader` in `waking.mojo`) with its own wake
registry, whose hook queues the task when something in it becomes ready. One
root poll is one executor turn: it runs queued tasks in FIFO order, each at
most once, while the root's transition budget lasts. A task requeued during the
turn waits for the next one, so the order stays deterministic. The root program
is a task too; its driver polls it when its turn comes.

The same tasks can later run on a work-stealing pool: a queue entry is the
right to run a task, and a task's state is reached only through it. The
executor owns its own fields; what wakes on other threads share with it (the
scheduler, a header's state) is used through immutable borrows of separately
allocated atomics, since a `mut` borrow is exclusive (see `waking.mojo`).

The transition slice belongs to the executor (`budget`): every task it runs
draws from it through its context, and only the executor's thread touches it.
This executor refills it once per turn, so the tasks of one root poll share it,
as before. A work-stealing worker (`pool.mojo`) runs the same tasks through
`run_body` and `settle`, but every fiber there owns its slice and refills it
for every run (`run_body`'s `fresh` flag), Cats Effect's per-fiber
auto-yield.

Seeded exploration (`TestControl(program, seed=s)`) adds the only choice
point, in `next`: an installed `_Explorer` takes the queued prefix that today's
turn would run next, a phase, and lets the seed pick which of its tasks runs
first. Tasks woken while a phase runs join a later phase, and a task that
already ran this turn ends it as the carry does, so choosing the first
candidate every time is today's FIFO turn exactly. Without an explorer, `next`
pays one branch on its field.
"""
from std.memory import ArcPointer, OwnedPointer
from std.os import abort
from fp._internal.waking import _Runtime, _Scheduler, _TaskHeader
from fp.effects._io_core import _Budget


struct ScheduleTrace(Copyable, Equatable, Writable):
    """A seed and the scheduling choices a `TestControl` run made with it.

    Each choice is the index of the task that ran first among the candidates
    of one phase: the fibers ready together, which the contract leaves
    unordered. Only phases with more than one candidate record a choice. The
    printed form, `seed=7 choices=2/3,0/2`, writes each choice as its index
    over its candidate count, and `parse` reads it back, so a trace printed by
    a failing check can be replayed with `TestControl(program, replay=trace)`.
    """
    var _seed: UInt64
    var _choices: List[Int]
    var _widths: List[Int]

    def __init__(out self, seed: UInt64):
        """Start an empty trace for a seed.

        Args:
            seed: The seed whose stream makes the choices.
        """
        self._seed = seed
        self._choices = List[Int]()
        self._widths = List[Int]()

    def seed(self) -> UInt64:
        """The seed of the run.

        Returns:
            The seed passed to `TestControl`, or the replayed trace's seed.
        """
        return self._seed

    def choices(self) -> List[Int]:
        """The choices made so far, in order.

        Returns:
            For each phase with several candidates, the index of the task run first.
        """
        return self._choices.copy()

    def __eq__(self, other: Self) -> Bool:
        """Compare seeds, choices and candidate counts.

        Args:
            other: The trace to compare with.

        Returns:
            True when both traces record the same run.
        """
        return self._seed == other._seed and self._choices == other._choices and self._widths == other._widths

    def __ne__(self, other: Self) -> Bool:
        """Report whether the traces differ.

        Args:
            other: The trace to compare with.

        Returns:
            True when the traces record different runs.
        """
        return not self == other

    def write_to(self, mut writer: Some[Writer]):
        """Write `seed=<seed> choices=<index>/<count>,...`.

        Args:
            writer: The destination.
        """
        writer.write("seed=", self._seed, " choices=")
        for i in range(len(self._choices)):
            if i:
                writer.write(",")
            writer.write(self._choices[i], "/", self._widths[i])

    @staticmethod
    def parse(text: String) raises -> Self:
        """Read a trace in its printed form.

        Args:
            text: `seed=<seed> choices=<index>/<count>,...`, as `write_to` writes it.

        Returns:
            The trace it describes.

        Raises:
            Error: The text is not a printed trace, or a choice is not below its count.
        """
        var bytes = text.as_bytes()
        var at = _expect(bytes, 0, "seed=")
        var seed = _digits(bytes, at)
        var trace = Self(seed[0])
        at = _expect(bytes, seed[1], " choices=")
        while at < len(bytes):
            if len(trace._choices):
                at = _expect(bytes, at, ",")
            var choice = _digits(bytes, at)
            at = _expect(bytes, choice[1], "/")
            var width = _digits(bytes, at)
            at = width[1]
            if width[0] < 2 or choice[0] >= width[0] or width[0] > UInt64(Int.MAX):
                raise Error("a schedule choice must be below its candidate count, which is at least 2")
            trace._choices.append(Int(choice[0]))
            trace._widths.append(Int(width[0]))
        return trace^


def _expect(bytes: Span[Byte, _], at: Int, literal: StaticString) raises -> Int:
    var expected = literal.as_bytes()
    if at + len(expected) > len(bytes):
        raise Error(String("a schedule trace expects '", literal, "'"))
    for i in range(len(expected)):
        if bytes[at + i] != expected[i]:
            raise Error(String("a schedule trace expects '", literal, "'"))
    return at + len(expected)


def _digits(bytes: Span[Byte, _], var at: Int) raises -> Tuple[UInt64, Int]:
    var start = at
    var value = UInt64(0)
    while at < len(bytes) and Int(bytes[at]) >= ord("0") and Int(bytes[at]) <= ord("9"):
        var digit = UInt64(Int(bytes[at]) - ord("0"))
        if value > (UInt64.MAX - digit) // 10:
            raise Error("a schedule trace number exceeds 64 bits")
        value = value * 10 + digit
        at += 1
    if at == start:
        raise Error("a schedule trace expects a number")
    return (value, at)


struct _Explorer(Movable):
    """The seeded choice point of an exploring `TestControl` (see the module docstring)."""
    var state: UInt64
    var trace: ScheduleTrace
    # The choices to repeat, with their candidate counts; empty unless replaying.
    var replay: ScheduleTrace
    # The current phase, in queue order.
    var phase: List[ArcPointer[_TaskHeader]]

    def __init__(out self, var replay: ScheduleTrace):
        """Explore with `replay.seed()`, first repeating `replay`'s choices."""
        self.state = replay.seed()
        self.trace = ScheduleTrace(replay.seed())
        self.replay = replay^
        self.phase = List[ArcPointer[_TaskHeader]]()

    def draw(mut self) -> UInt64:
        """The next splitmix64 output of the seed's stream."""
        self.state += 0x9E3779B97F4A7C15
        var z = self.state
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) * 0x94D049BB133111EB
        return z ^ (z >> 31)

    def choose(mut self, width: Int) -> Int:
        """Choose among `width` candidates, repeating the replayed choice while one remains.

        The stream is drawn on every choice, replayed or not, so a replay
        that runs out continues as its seed would.
        """
        var chosen = Int(self.draw() % UInt64(width))
        var index = len(self.trace._choices)
        if index < len(self.replay._choices):
            if self.replay._widths[index] != width:
                abort(String("TestControl replay diverged at choice ", index, ": the trace has ", self.replay._widths[index], " candidates, the run has ", width))
            chosen = self.replay._choices[index]
        self.trace._choices.append(chosen)
        self.trace._widths.append(width)
        return chosen

    def next(mut self, scheduler: ArcPointer[_Scheduler], mut carry: Optional[ArcPointer[_TaskHeader]], turn: UInt64) -> Optional[ArcPointer[_TaskHeader]]:
        """The executor's `next` with a seeded choice within each phase."""
        if not len(self.phase):
            if carry:
                if carry.value()[].turn == turn:
                    return None
                self.phase.append(carry.take())
            while True:
                var task = scheduler[].pop()
                if not task:
                    break
                if task.value()[].turn == turn:
                    carry = task^
                    break
                self.phase.append(task.take())
            if not len(self.phase):
                return None
        var index = 0
        if len(self.phase) > 1:
            index = self.choose(len(self.phase))
        return Optional(self.phase.pop(index))


struct _Executor(Movable):
    """The scheduling state of one root on the current-thread profile."""
    var scheduler: ArcPointer[_Scheduler]
    var root: ArcPointer[_TaskHeader]
    var turn: UInt64
    # A task popped in the turn in which it already ran: first in the next turn.
    var carry: Optional[ArcPointer[_TaskHeader]]
    # This executor's transition slice and the root's read-only configuration.
    var budget: ArcPointer[_Budget]
    # Installed only by an exploring TestControl; behind a pointer so the
    # executor stays as small as before.
    var explorer: Optional[OwnedPointer[_Explorer]]

    def __init__(out self, runtime: _Runtime, var budget: _Budget):
        self.budget = ArcPointer(budget^)
        self.scheduler = runtime.scheduler()
        var root = _TaskHeader.for_root()
        root.registry = Optional(runtime.copy())
        self.root = ArcPointer(root^)
        self.turn = 0
        self.carry = None
        self.explorer = None

    def ready(self) -> Bool:
        """Whether a task is queued."""
        return Bool(self.carry) or self.scheduler[].queued() > 0 or (Bool(self.explorer) and len(self.explorer.value()[].phase) > 0)

    def begin_turn(mut self):
        """Start a turn with a fresh slice, shared by the tasks run in it."""
        self.turn += 1
        self.budget[].refill()

    def spent(self) -> Bool:
        return self.budget[].remaining <= 0

    def transitions(self) -> Int:
        """Transitions consumed so far, across every task this executor ran."""
        return self.budget[].consumed

    def begin_run(self, task: ArcPointer[_TaskHeader]):
        """The per-task-run hook; the current-thread profile shares one slice per turn.

        A work-stealing worker instead runs each task with `fresh` set, so the
        task refills its own slice and each run gets a full one wherever it runs.
        """
        pass

    def next(mut self) -> Optional[ArcPointer[_TaskHeader]]:
        """The next task to run in this turn, marked running; none ends the turn."""
        var task: Optional[ArcPointer[_TaskHeader]]
        if self.explorer:
            return self._next_explored()
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
        _TaskHeader.begin_run(task.value())
        return task^

    @no_inline
    def _next_explored(mut self) -> Optional[ArcPointer[_TaskHeader]]:
        """`next` with a seeded choice; out of line, so the default path stays as it was."""
        var task = self.explorer.value()[].next(self.scheduler, self.carry, self.turn)
        if task:
            task.value()[].turn = self.turn
            _TaskHeader.begin_run(task.value())
        return task^

    def run(self, task: ArcPointer[_TaskHeader]):
        """Run a fiber task once, then park, requeue, or retire it."""
        self.begin_run(task)
        _Executor.settle(task, _Executor.run_body(task, False))

    @staticmethod
    def run_body(task: ArcPointer[_TaskHeader], fresh: Bool) -> Bool:
        """Run a task's body once, marked running by `next` or a pool worker; true when finished.

        `fresh` gives the run a full transition slice of its own (`_TaskRun`):
        a work-stealing worker passes true, this executor false.
        """
        var run = task[].run
        return run(task[].body, fresh)

    @staticmethod
    def settle(task: ArcPointer[_TaskHeader], done: Bool):
        if done:
            task[].registry.value().detach()
            _TaskHeader.finish(task)
        else:
            task[].registry.value().park(task)

    def fiber_slots(self) -> Int:
        return self.scheduler[].fiber_slots()
