"""Typed resumable work with no coroutine intrinsics or context-switch ABI."""
from std.atomic import Atomic
from std.memory import ArcPointer, OwnedPointer
from std.time import monotonic, sleep
from std.os import abort
from fp.effects import IOContext, CancellationToken, Outcome, EffectFailure
from fp.effects._io_core import _settle
from fp.data import Result, Ok


struct Signal(Copyable):
    var _revision: ArcPointer[Atomic[UInt64]]

    def __init__(out self):
        self._revision = ArcPointer(Atomic(UInt64(0)))

    def revision(self) -> UInt64:
        return self._revision[].load()

    def notify(self):
        var old = self._revision[].load()
        while True:
            if old == UInt64.MAX:
                abort("signal revision exhausted")
            if self._revision[].compare_exchange(old, old + 1):
                return


@fieldwise_init
struct _Wake(Copyable):
    var signal: Optional[Signal]
    var revision: UInt64
    var deadline: Optional[Int]
    var token: Optional[CancellationToken]

    def ready(self, now: Int) -> Bool:
        return (Bool(self.signal) and self.signal.value().revision() != self.revision
            or Bool(self.deadline) and now >= self.deadline.value()
            or Bool(self.token) and self.token.value().requested())


struct Wait(Copyable):
    var signal: Optional[Signal]
    var revision: UInt64
    var deadline: Optional[Int]
    var interruptible: Bool
    var runnable: Bool
    var _wakes: List[_Wake]

    def __init__(out self):
        self.signal = None
        self.revision = 0
        self.deadline = None
        self.interruptible = True
        self.runnable = True
        self._wakes = List[_Wake]()

    @staticmethod
    def never() -> Self:
        var wait = Self()
        wait.runnable = False
        return wait^

    def include[E: Movable & Deinitable](mut self, other: Self, context: IOContext[E]):
        """Flatten owned descriptors, binding cancellation to its actual token."""
        self.runnable = self.runnable or other.runnable
        if other.signal or other.deadline:
            self._wakes.append(_Wake(other.signal.copy(), other.revision, other.deadline.copy(), None))
        if other.interruptible and not context._masked:
            self._wakes.append(_Wake(None, 0, None, Optional(context._token.copy())))
        for wake in other._wakes:
            self._wakes.append(wake.copy())

    @staticmethod
    def changed(signal: Signal, revision: UInt64) -> Self:
        var wait = Self.never()
        wait.signal = Optional(signal.copy())
        wait.revision = revision
        return wait^

    @staticmethod
    def until(deadline: Int) -> Self:
        var wait = Self.never()
        wait.deadline = Optional(deadline)
        return wait^

    def ready[E: Movable & Deinitable](self, now: Int, context: IOContext[E]) -> Bool:
        if self.interruptible and context.canceled():
            return True
        if self.signal and self.signal.value().revision() != self.revision:
            return True
        if self.deadline and now >= self.deadline.value():
            return True
        for wake in self._wakes:
            if wake.ready(now):
                return True
        return self.runnable


struct Step[T: Movable & Deinitable, E: Movable & Deinitable](Movable):
    # Outer absence means pending; inner absence is a completed cancellation.
    var completed: Optional[Outcome[Self.T, Self.E]]
    var wait: Wait

    @staticmethod
    def ready(var outcome: Outcome[Self.T, Self.E]) -> Self:
        return Self(Optional(outcome^), Wait())

    @staticmethod
    def pending(var wait: Wait) -> Self:
        return Self(None, wait^)

    def outcome(deinit self) -> Outcome[Self.T, Self.E]:
        return self.completed.take()

    def waiting(deinit self) -> Wait:
        return self.wait^

    def __init__(out self, var completed: Optional[Outcome[Self.T, Self.E]], var wait: Wait):
        self.completed = completed^
        self.wait = wait^


trait Machine(Movable, Deinitable):
    comptime Value: Movable & Deinitable
    comptime Error: Movable & Deinitable
    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        ...


struct _Slot[P: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable](Movable):
    """Private running storage. Only a linear root may own entered slots."""
    # Native typed indirection bounds frame size for deeply nested bind types.
    var _program: Optional[OwnedPointer[Self.P]]
    var _result: Optional[Outcome[Self.T, Self.E]]
    var _wait: Wait
    var entered: Bool
    var polls: Int

    def __init__(out self, var program: Self.P):
        self._program = Optional(OwnedPointer(program^))
        self._result = None
        self._wait = Wait()
        self.entered = False
        self.polls = 0

    def __deinit__(deinit self):
        if self.entered and not self.done():
            abort("entered execution slot abandoned before cleanup completed")

    def done(self) -> Bool:
        return not self._program

    def ready(self, now: Int, context: IOContext[Self.E]) -> Bool:
        return not self.done() and self._wait.ready(now, context)

    def enter(mut self, context: IOContext[Self.E]) -> Bool:
        if not self.entered and context.canceled():
            self.accept(Step[Self.T, Self.E].ready(None), context)
            return False
        self.entered = True
        self.polls += 1
        return True

    def accept(mut self, var step: Step[Self.T, Self.E], context: IOContext[Self.E]):
        if step.completed:
            self._result = Optional(_settle(step^.outcome(), context))
            self._program = None
        else:
            self._wait = step^.waiting()

    def failed(self) -> Bool:
        return self.done() and (not self._result.value() or self._result.value().value().is_err())

    def take_outcome(mut self) -> Outcome[Self.T, Self.E]:
        if not self.done():
            abort("unfinished task cannot be consumed")
        return self._result.take()


def _tick[P: Machine](mut slot: _Slot[P, P.Value, P.Error], context: IOContext[P.Error]) -> Bool:
    if not slot.ready(monotonic(), context):
        return False
    if slot.enter(context):
        var step = slot._program.value()[].poll(context)
        slot.accept(step^, context)
    return True


struct Task[P: Machine](Movable, not Deinitable):
    """Linear owner of the complete execution subtree, including cleanup."""
    var _slot: _Slot[Self.P, Self.P.Value, Self.P.Error]
    var context: IOContext[Self.P.Error]

    def __init__(out self, var program: Self.P, token: CancellationToken):
        self._slot = _Slot[Self.P, Self.P.Value, Self.P.Error](program^)
        self.context = IOContext[Self.P.Error](token.copy(), False)

    def done(self) -> Bool:
        return self._slot.done()

    def ready(self, now: Int) -> Bool:
        return self._slot.ready(now, self.context)

    def cancel(self):
        self.context.request_cancel()

    def tick(mut self) -> Bool:
        return _tick(self._slot, self.context)

    def finish(deinit self) -> Outcome[Self.P.Value, Self.P.Error]:
        return self._slot.take_outcome()


def run[P: Machine](var program: P, token: CancellationToken) -> Outcome[P.Value, P.Error]:
    var task = Task(program^, token)
    while not task.done():
        if not task.tick():
            sleep(0.001)
    return task^.finish()


def run[P: Machine](var program: P) -> Outcome[P.Value, P.Error]:
    return run(program^, CancellationToken())


def run_pair[P: Machine, Q: Machine](var first: P, var second: Q,
    first_token: CancellationToken, second_token: CancellationToken
) -> Tuple[Outcome[P.Value, P.Error], Outcome[Q.Value, Q.Error]]:
    """Finite batch driver; each ready task gets at most one poll per round."""
    var left = Task(first^, first_token)
    var right = Task(second^, second_token)
    while not left.done() or not right.done():
        var progress = left.tick()
        progress = right.tick() or progress
        if not progress:
            # Tasks stay parked; this host-idle strategy is deliberately basic.
            sleep(0.001)
    return (left^.finish(), right^.finish())


struct Sleep[E: Movable & Deinitable](Machine):
    var _duration: Int
    var _deadline: Optional[Int]
    comptime Value = NoneType
    comptime Error = Self.E

    def __init__(out self, nanoseconds: Int):
        if nanoseconds < 0 or nanoseconds > 1000000000000000000:
            abort("sleep duration outside supported range")
        self._duration = nanoseconds
        self._deadline = None

    def poll(mut self, context: IOContext[Self.E]) -> Step[NoneType, Self.E]:
        if context.canceled():
            return Step[NoneType, Self.E].ready(None)
        var now = monotonic()
        if not self._deadline:
            if now > Int.MAX - self._duration:
                abort("monotonic deadline overflow")
            self._deadline = Optional(now + self._duration)
        if now >= self._deadline.value():
            var unit: NoneType = None
            return Step[NoneType, Self.E].ready(Optional(Result[NoneType, EffectFailure[Self.E]](Ok(unit))))
        var wait = Wait.until(self._deadline.value())
        wait.interruptible = not context._masked
        return Step[NoneType, Self.E].pending(wait^)
