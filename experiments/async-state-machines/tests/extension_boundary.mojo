"""A leaf reports completion through the host without accessing scheduler fields."""
from std.memory import ArcPointer
from fp.effects import IOContext, EffectFailure
from fp.data import Result, Ok
from fp.functions import pipeline
from fp.effects._async.family import Async, Machine
from fp.effects._async.kernel import Step, Wait, Signal
from fp.effects._async.host import Driver
from foundation import check


@fieldwise_init
struct External(Machine):
    comptime Family = Async[Int]
    comptime Value = Int
    comptime Error = Int
    var signal: Signal
    var state: ArcPointer[Int]
    var notify_during_poll: Bool
    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
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


def main():
    var signal = Signal()
    var state = ArcPointer(0)
    var driver = Driver(pipeline(External(signal.copy(), state.copy(), False)).map(add).get())
    var first = driver.poll()
    check(not first.completed and not first.runnable, "leaf parks through supported wait descriptor")
    state[] = 42
    signal.notify()
    while not driver.poll().completed:
        pass
    var result = driver^.finish()
    check(result.take()._take_ok() == 43, "host completion flows through selected Pipeline")
    state[] = 0
    var raced = Driver(External(signal.copy(), state.copy(), True))
    while not raced.poll().completed:
        pass
    var second = raced^.finish()
    check(second.take()._take_ok() == 42, "notification before registration is preserved")
    print("extension boundary: cooperative host completion, selected family, notification before parking")
