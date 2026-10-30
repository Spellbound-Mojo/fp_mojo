"""Sequential start/join churn reuses fiber slots and wake registrations."""
from std.os import abort
from fp.callables import OnceUnary
from fp.effects import CancellationToken, Outcome
from fp._internal.cells import _lock_metadata
from fp.effects._async.engine import IO, Fiber
from fp.effects._async.kernel import Driver, Clock, IORuntimeConfig, Machine


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


@fieldwise_init
struct Cycle(OnceUnary):
    """Start a child, join it, and continue with the next cycle."""
    var limit: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var count: Int) -> IO[Int, Int]:
        if count == self.limit:
            return IO[Int, Int].pure(count)
        return IO[Int, Int].pure(count).start().flat_map(Join(self.limit))


@fieldwise_init
struct Join(OnceUnary):
    var limit: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join().flat_map(Next(self.limit))


@fieldwise_init
struct Next(OnceUnary):
    var limit: Int
    comptime Arg = Outcome[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> IO[Int, Int]:
        check(Bool(outcome) and outcome.value().is_ok(), "each child succeeds")
        var count = outcome.take()._take_ok()
        return IO[Int, Int].pure(count + 1).flat_map(Cycle(self.limit))


def registrations[P: Machine](driver: Driver[P]) -> Int:
    var guard = _lock_metadata(driver.task.context._runtime.value()._cell)
    return len(guard.cell[].slot.value().nodes)


def main() raises:
    comptime cycles = 1_000_000
    var program = IO[Int, Int].pure(0).flat_map(Cycle(cycles))
    var driver = Driver(program^, CancellationToken(), Clock(), IORuntimeConfig())
    var slots = 0
    var nodes = 0
    while True:
        var progress = driver.poll(64)
        if progress.completed:
            break
        slots = max(slots, driver.task._slot._program.value()[]._fiber_slots())
        nodes = max(nodes, registrations(driver))
    var outcome = driver^.finish()
    check(Bool(outcome) and outcome.value().is_ok(), "the owner completes")
    check(outcome.take()._take_ok() == cycles, "every cycle joined its child")
    check(slots == 1, "one fiber slot serves every sequential start")
    check(nodes <= 4, "wake registrations are reused across cycles")
    print("fiber churn: a million start/join cycles in one slot and constant registrations")
