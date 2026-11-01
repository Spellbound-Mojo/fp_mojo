"""Unopened children, mask boundaries, wake races and mixed readiness."""
from std.memory import ArcPointer
from std.time import sleep, monotonic
from fp.effects import IOContext, CancellationToken
from state_machine import Machine, Step, Wait, Signal, Task, Sleep, bind, run
from foundation import check, success, failure, Failure, Waiter, both
from children import Terminal
from fp.callables import OnceUnary
from state_machine import Pure, pure


@fieldwise_init
struct FailNow(Machine):
    var stats: ArcPointer[List[Int]]
    comptime Value = Int
    comptime Error = Failure
    def poll(mut self, context: IOContext[Failure]) -> Step[Int, Failure]:
        return failure[Int](91, self.stats)


@fieldwise_init
struct Next(OnceUnary):
    var calls: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = Pure[String, Failure]
    def call_once(deinit self, var value: Int) -> Self.Out:
        self.calls[] += 1
        return pure[Failure](String(value))


@fieldwise_init
struct Masked[P: Machine](Machine):
    var program: Self.P
    comptime Value = Self.P.Value
    comptime Error = Self.P.Error
    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        var step = self.program.poll(context._mask())
        step._wait._interruptible = False
        return step^


@fieldwise_init
struct Gate(Machine):
    var signal: Signal
    var calls: ArcPointer[Int]
    comptime Value = Int
    comptime Error = Failure
    def poll(mut self, context: IOContext[Failure]) -> Step[Int, Failure]:
        check(not context._masked and not context.canceled(), "children start independently unmasked")
        self.calls[] += 1
        if self.calls[] == 1:
            return .pending(Wait.changed(self.signal, self.signal.revision()))
        return success[Int, Failure](self.calls[])


def main():
    for entered in range(3):
        var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
        var signal = Signal()
        var task = Task(both(Terminal(signal.copy(), stats.copy(), 0, 0, False), Terminal(signal.copy(), stats.copy(), 1, 0, False)), CancellationToken())
        for _ in range(entered):
            # After the first tick both fibers are parked; later ticks may find nothing ready.
            _ = task.tick()
        task.cancel()
        while not task.done():
            check(task.tick(), "drain entered children")
        var outcome = task^.finish()
        check(not outcome, "parent cancellation")
        # The first tick starts both fibers; canceled before it, neither runs.
        check(stats[][0] == (0 if entered == 0 else 2), "left only runs when entered")
        check(stats[][1] == (0 if entered == 0 else 2), "unopened sibling skipped")
    var failed_stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
    var failed = run(both(FailNow(failed_stats.copy()), Terminal(Signal(), failed_stats.copy(), 1, 0, False)))
    # Both fibers start in the same root poll, so the sibling may have entered;
    # the failure cancels it, and the pair completes only after it drains.
    check(failed.value().is_err(), "immediate failure cancels the sibling and fails the pair")
    var failure_value = failed.take()._take_err()
    check(failure_value.canceled and failure_value.errors.first().code == 91, "unopened sibling cancellation retained")
    var next_calls = ArcPointer(0)
    var stopped = run(bind(FailNow(failed_stats.copy()), Next(next_calls.copy())))
    check(stopped.value().is_err() and next_calls[] == 0, "source failure skips continuation")
    var changed = run(bind(pure[Failure](17), Next(next_calls.copy())))
    check(changed.take()._take_ok() == "17" and next_calls[] == 1, "bind changes result type")
    var a = Signal()
    var b = Signal()
    var calls_a = ArcPointer(0)
    var calls_b = ArcPointer(0)
    var masked = Task(Masked(both(Gate(a.copy(), calls_a.copy()), Gate(b.copy(), calls_b.copy()))), CancellationToken())
    check(masked.tick(), "masked group enters both children in one tick")
    _ = masked.tick()
    masked.cancel()
    check(not masked.tick(), "masked parent request is not forwarded")
    a.notify()
    b.notify()
    while not masked.done():
        check(masked.tick(), "children finish under parent mask")
    var canceled = masked^.finish()
    check(not canceled and calls_a[] == 2 and calls_b[] == 2, "outer unmask observes deferred cancellation")
    var one = ArcPointer(List[Int]([0, 0]))
    var two = ArcPointer(List[Int]([0, 0]))
    var raced = run(both(Waiter(Signal(), one.copy(), True), Waiter(Signal(), two.copy(), True)))
    check(raced.value().is_ok() and one[][1] == 2 and two[][1] == 2, "wake before parking survives union")
    var signal = Signal()
    var calls = ArcPointer(0)
    var mixed = Task(both(Sleep[Failure](5000000), Gate(signal.copy(), calls.copy())), CancellationToken())
    var start = monotonic()
    check(mixed.tick(), "timer and signal both park in one tick")
    _ = mixed.tick()
    signal.notify()
    check(mixed.tick() and calls[] == 2, "signal progresses independently of timer")
    while not mixed.done():
        if not mixed.tick():
            sleep(0.001)
    var completed = mixed^.finish()
    check(completed.value().is_ok() and monotonic() - start >= 5000000, "union retains timer deadline")
    print("wakes: unopened cancellation, sibling failure, parent masks, notification races, timer/signal union")
