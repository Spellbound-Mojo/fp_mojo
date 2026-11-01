"""One transition budget per root poll, shared by nested run loops; cancellation check intervals."""
from std.memory import ArcPointer
from fp.callables import OnceUnary
from fp.effects import IOContext, CancellationToken, EffectFailure
from fp.effects._async.engine import IO
from fp.effects._async.kernel import Driver, Clock, IORuntimeConfig, Machine, Step, Wait
from foundation import check, success


@fieldwise_init
struct Loop(OnceUnary):
    """Tail recursion through a continuation; counts the steps it ran."""
    var limit: Int
    var steps: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var value: Int) -> IO[Int, Int]:
        self.steps[] += 1
        if value == self.limit:
            return IO[Int, Int].pure(value)
        return IO[Int, Int].pure(value + 1).flat_map(Self(self.limit, self.steps^))


@fieldwise_init
struct Cancel(OnceUnary):
    """Request cancellation of the root once a step is reached."""
    var at: Int
    var token: CancellationToken
    var steps: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var value: Int) -> IO[Int, Int]:
        self.steps[] += 1
        if value == self.at:
            self.token.cancel()
        return IO[Int, Int].pure(value + 1).flat_map(Self(self.at, self.token^, self.steps^))


@fieldwise_init
struct Forever(Machine):
    comptime Value = Int
    comptime Error = Int

    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        if context.canceled():
            return .ready(None)
        return .pending(Wait.never())


def chain(limit: Int, steps: ArcPointer[Int]) -> IO[Int, Int]:
    return IO[Int, Int].pure(0).flat_map(Loop(limit, steps.copy()))


@fieldwise_init
struct Report(Copyable):
    var polls: Int
    var transitions: Int
    var largest: Int


def drive[P: Machine](var driver: Driver[P]) -> Report:
    """Poll one root poll at a time to completion, recording transitions per poll."""
    var report = Report(0, 0, 0)
    while True:
        var progress = driver.poll(1)
        report.polls += progress.polls
        report.transitions += progress.transitions
        report.largest = max(report.largest, progress.transitions)
        if progress.completed:
            break
    _ = driver^.finish()
    return report^


def long_chain() raises:
    var steps = ArcPointer(0)
    var config = IORuntimeConfig(1, 1024)
    var report = drive(Driver(chain(100_000, steps), CancellationToken(), Clock(), config))
    check(steps[] == 100_001, "every step ran")
    check(report.largest <= 1024, "no root poll exceeds the yield threshold")
    var expected = (report.transitions + 1023) // 1024
    check(report.polls == expected or report.polls == expected + 1, "a long chain takes about transitions/threshold root polls")


def nested_children() raises:
    var left = ArcPointer(0)
    var right = ArcPointer(0)
    var config = IORuntimeConfig(1, 64)
    var report = drive(Driver(chain(5_000, left).both(chain(5_000, right)), CancellationToken(), Clock(), config))
    check(left[] == 5_001 and right[] == 5_001, "both children ran to completion")
    check(report.largest <= 64, "nested run loops share one budget per root poll")
    check(report.polls > 10_000 // 64, "children yield to the host instead of running to completion")


def fair_children() raises:
    var left = ArcPointer(0)
    var right = ArcPointer(0)
    var config = IORuntimeConfig(1, 2)
    var driver = Driver(chain(1_000, left).both(chain(1_000, right)), CancellationToken(), Clock(), config)
    for _ in range(200):
        _ = driver.poll(1)
    var shared = left[] > 0 and right[] > 0 and left[] < 1_001 and right[] < 1_001
    driver.cancel()
    while not driver.poll(64).completed:
        pass
    _ = driver^.finish()
    check(shared, "both children advance while neither has finished")


def masked_cleanup() raises:
    var cleanup = ArcPointer(0)
    var config = IORuntimeConfig(1, 64)
    var body = IO[Int, Int].lift(Forever()).guarantee(chain(5_000, cleanup).map(drop))
    var driver = Driver(body^, CancellationToken(), Clock(), config)
    _ = driver.poll(1)
    driver.cancel()
    var polls = 0
    var largest = 0
    while True:
        var progress = driver.poll(1)
        polls += 1
        largest = max(largest, progress.transitions)
        if progress.completed:
            break
    check(not driver^.finish(), "the body is canceled")
    check(cleanup[] == 5_001, "masked cleanup completes every step under cancellation")
    check(polls > 5_000 // 64 and largest <= 64, "masked cleanup yields between root polls")


def drop(var value: Int) -> NoneType:
    return None


def check_interval(every: Int) raises:
    var token = CancellationToken()
    var steps = ArcPointer(0)
    var config = IORuntimeConfig(every, 1024)
    var program = IO[Int, Int].pure(0).flat_map(Cancel(10, token.copy(), steps.copy()))
    _ = drive(Driver(program^, token, Clock(), config))
    var extra = steps[] - 11
    check(extra >= 0 and extra < every, "cancellation is observed within the check interval")
    if every == 1:
        check(extra == 0, "checking every bind stops at the next handoff")


def validation():
    var rejected = 0
    try:
        _ = IORuntimeConfig(0, 1024)
    except:
        rejected += 1
    try:
        _ = IORuntimeConfig(3, 1024)
    except:
        rejected += 1
    try:
        _ = IORuntimeConfig(8, -8)
    except:
        rejected += 1
    check(rejected == 3, "invalid thresholds are rejected at construction")
    var defaults = IORuntimeConfig()
    check(defaults.cancelation_check_threshold == 1 and defaults.auto_yield_threshold == 1024, "defaults check every bind and yield every 1,024 transitions")


def main() raises:
    long_chain()
    nested_children()
    fair_children()
    masked_cleanup()
    check_interval(1)
    check_interval(8)
    validation()
    print("io budget: shared per-poll transitions, nested children, fair children, masked cleanup, check intervals, validation")
