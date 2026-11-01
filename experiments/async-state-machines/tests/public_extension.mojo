"""A lifted leaf reports completion through the host without accessing scheduler fields."""
from std.os import abort
from fp.effects import Outcome, EffectFailure, fold_outcome, CancellationToken
from std.memory import ArcPointer
from fp.effects.async_runtime.protocols import Context, Machine, Step, Wait, Signal
from fp.data import Result, Ok
from fp.functions import pipeline
from fp.effects.async_runtime import IO, Driver, Clock, Duration, Instant


@fieldwise_init
struct External(Machine):
    comptime Value = Int
    comptime Error = Int
    var signal: Signal
    var state: ArcPointer[Int]
    var notify_during_poll: Bool
    def poll(mut self, context: Context[Int]) -> Step[Int, Int]:
        if context.canceled():
            return .ready(None)
        var revision = self.signal.revision()
        if self.state[] == 42:
            return .ready(Optional(Result[Int, EffectFailure[Int]](Ok(self.state[]))))
        if self.notify_during_poll:
            self.state[] = 42
            self.signal.notify()
        return .pending(Wait.changed(self.signal, revision))


def add(var value: Int) -> Int:
    return value + 1



struct Timed(Machine):
    comptime Value = Int
    comptime Error = Int
    var duration: Duration
    var deadline: Optional[Instant]
    def __init__(out self, var duration: Duration):
        self.duration = duration^
        self.deadline = None
    def poll(mut self, context: Context[Int]) -> Step[Int, Int]:
        if context.canceled():
            return .ready(None)
        if not self.deadline:
            self.deadline = Optional(context.now() + self.duration)
        if context.now() >= self.deadline.value():
            return .ready(Optional(Result[Int, EffectFailure[Int]](Ok(42))))
        return .pending(Wait.until(self.deadline.value()))

def main() raises:
    var signal = Signal()
    var state = ArcPointer(0)
    var driver = Driver(pipeline(IO[Int, Int].lift(External(signal.copy(), state.copy(), False))).map(add).get())
    var first = driver.poll()
    check(not first.completed and not first.runnable, "leaf parks through supported wait descriptor")
    state[] = 42
    signal.notify()
    while not driver.poll().completed:
        pass
    var result = driver^.finish()
    check(take_int(result^) == 43, "host completion flows through a lifted leaf and Pipeline")
    state[] = 0
    var raced = Driver(External(signal.copy(), state.copy(), True))
    while not raced.poll().completed:
        pass
    var second = raced^.finish()
    check(take_int(second^) == 42, "notification before registration is preserved")
    var clock = Clock.manual(Int.MAX)
    var duration = Duration.nanoseconds(7)
    var timed = Driver(Timed(duration.copy()), CancellationToken(), clock)
    var pending = timed.poll()
    check(pending.deadline.value() == clock.now() + duration, "Context shares the wide inherited clock")
    try:
        clock.advance_to(pending.deadline.value())
    except error:
        abort("valid manual advance rejected")
    while not timed.poll().completed:
        pass
    check(take_int(timed^.finish()) == 42, "custom opaque timer completes past Int.MAX")
    print("extension boundary: cooperative host completion, lifted leaf in Pipeline, notification before parking")


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def success(value: Int) -> Int:
    return value


def failure(var value: EffectFailure[Int]) -> Int:
    abort("unexpected failure")


def canceled() -> Int:
    abort("unexpected cancellation")


def take_int(var outcome: Outcome[Int, Int]) -> Int:
    return fold_outcome(outcome^, success, failure, canceled)
