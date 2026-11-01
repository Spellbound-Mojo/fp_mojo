"""TestControl: virtual time, ticking, deadlock against awaiting external events, and delivery between ticks."""
from std.memory import ArcPointer
from std.os import abort
from fp.callables import OnceUnary
from fp.data import Result, Ok
from fp.effects import Outcome, EffectFailure
from fp.effects.async_runtime import IO, Deferred, Completion, Duration, Instant, TestControl, run


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def ms(value: Int) -> Duration:
    try:
        return Duration.milliseconds(value)
    except:
        abort("a valid duration")


def nanos(value: Optional[Duration]) -> Int:
    if not value:
        return -1
    return value.value().to_nanoseconds()


def value_of[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    if not outcome or not outcome.value().is_ok():
        abort("expected a success")
    return outcome.take()._take_ok()


def ten(var unit: NoneType) -> Int:
    return 10


def since_zero(now: Instant) -> Int:
    return now.since(Instant()).to_nanoseconds()


def virtual_sleep() raises:
    var control = TestControl(IO[NoneType, Int].sleep(ms(5)).map(ten).timed())
    control.tick()
    check(not control.is_completed(), "tick does not move time")
    check(nanos(control.next_interval()) == 5_000_000, "next_interval reports the sleep")
    control.tick_all()
    check(control.is_completed() and since_zero(control.now()) == 5_000_000, "tick_all advances to the deadline")
    var measured = value_of(control^.results())
    check(measured[1] == 10 and measured[0].to_nanoseconds() == 5_000_000, "the program measures virtual time")


def tick_and_advance() raises:
    var control = TestControl(IO[NoneType, Int].sleep(ms(10)).map(ten))
    check(control.tick_one(), "the first poll runs work")
    control.tick()
    check(not control.tick_one(), "a sleeping program has nothing to run")
    control.advance(ms(4))
    check(not control.is_completed() and nanos(control.next_interval()) == 6_000_000, "advance moves time without running")
    control.advance_and_tick(ms(6))
    check(control.is_completed(), "advance_and_tick reaches the deadline and runs")
    check(value_of(control^.results()) == 10, "the sleep completes on virtual time")


@fieldwise_init
struct Again(OnceUnary):
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        return IO[NoneType, Int].sleep(ms(3))


def tick_for() raises:
    var control = TestControl(IO[NoneType, Int].sleep(ms(3)).flat_map(Again()).map(ten))
    control.tick_for(ms(4))
    check(not control.is_completed() and since_zero(control.now()) == 4_000_000, "tick_for stops at its end")
    control.tick_for(ms(2))
    check(control.is_completed() and since_zero(control.now()) == 6_000_000, "tick_for runs through each deadline")
    check(value_of(control^.results()) == 10, "both sleeps complete")


def deadlock() raises:
    var deferred = Deferred[Int]()
    var control = TestControl(deferred.get[Int]())
    control.tick_all()
    check(not control.is_completed() and control.is_deadlocked(), "a read nothing can complete is deadlocked")
    # The documented assumption: the test itself can still complete a shared value.
    check(value_of(run(deferred.complete[Int](4))), "the host completes the value")
    control.tick()
    check(value_of(control^.results()) == 4, "the completed read resumes at the next tick")


@fieldwise_init
struct Register(OnceUnary):
    """Keep the completion so the test can deliver the event later."""
    var slot: ArcPointer[Optional[Completion[Int, Int]]]
    comptime Arg = Completion[Int, Int]
    comptime Out = NoneType

    def call_once(deinit self, var completion: Completion[Int, Int]) -> NoneType:
        self.slot[] = Optional(completion^)
        return None


def deliver(slot: ArcPointer[Optional[Completion[Int, Int]]], value: Int):
    check(Bool(slot[]), "the registration is live")
    check(slot[].value().complete(Optional(Result[Int, EffectFailure[Int]](Ok(value)))), "the first completion wins")


@fieldwise_init
struct Sum(OnceUnary):
    comptime Arg = Tuple[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var pair: Tuple[Int, Int]) -> Int:
        return pair[0] * 10 + pair[1]


def external_events() raises:
    var left = ArcPointer(Optional[Completion[Int, Int]]())
    var right = ArcPointer(Optional[Completion[Int, Int]]())
    var program = IO[Int, Int].async_(Register(left.copy())).both(IO[Int, Int].async_(Register(right.copy()))).map(Sum())
    var control = TestControl(program^)
    control.tick_all()
    check(not control.is_completed() and not control.is_deadlocked(), "live registrations await external events")
    deliver(right, 2)
    deliver(left, 1)
    control.tick()
    check(control.is_completed(), "events delivered between ticks are observed at the next tick")
    check(value_of(control^.results()) == 12, "each side receives its own event")


def cancellation() raises:
    var control = TestControl(IO[Int, Int].never())
    control.tick_all()
    check(control.is_deadlocked(), "never waits for nothing")
    control.request_cancel()
    control.tick()
    check(control.is_completed(), "cancellation completes the program")
    check(not control^.results(), "the outcome is canceled")


def main() raises:
    virtual_sleep()
    tick_and_advance()
    tick_for()
    deadlock()
    external_events()
    cancellation()
    print("test control: virtual sleeps, tick and advance, tick_for, deadlock, external events between ticks, cancellation")
