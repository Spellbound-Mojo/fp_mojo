"""Wide manual time cannot truncate masked withdrawal or its captured owners."""
from std.memory import ArcPointer
from fp.effects import CancellationToken, Outcome
from fp.effects._async.application import callback, guarantee, sleep, delay
from fp.effects._async.callbacks import Completion
from fp.effects._async.host import Clock, Driver
from fp.effects._async.time import Duration
from foundation import check
from instant_timers import advance


@fieldwise_init
struct Guard(Movable):
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1


def withdrawal_case(fail: Bool) raises:
    var clock = Clock.manual(Int.MAX)
    var span = Duration.nanoseconds(7)
    var saved = ArcPointer(Optional[Completion[Int, Int]]())
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var guard = Guard(drops.copy())
    def register(done: Completion[Int, Int]) {saved}:
        saved[] = Optional(done.copy())
    def release() raises Int {var guard^, calls, fail}:
        calls[] += 1
        check(guard.drops[] == 0, "withdrawal capture lives through the timer")
        if fail:
            raise 42
    var cleanup = guarantee(sleep[Int](span), delay[Int](release^))
    var driver = Driver(callback(register, cleanup^), CancellationToken(), clock)
    var entered = driver.poll()
    check(not entered.completed and not entered.runnable and Bool(saved[]), "registration enters and parks")
    driver.request_cancel()
    var pending = driver.poll()
    check(not pending.completed and not pending.runnable and pending.deadline.value() == clock.now() + span, "masked withdrawal retains its wide deadline")
    check(calls[] == 0 and drops[] == 0, "capture retained while timer is parked")
    check(not saved[].value().complete(Outcome[Int, Int]()), "late producer rejected after withdrawal starts")
    advance(clock, pending.deadline.value())
    while not driver.poll().completed:
        pass
    var result = driver^.finish()
    check(calls[] == 1 and drops[] == 1, "withdrawal and capture destruction complete exactly once")
    if fail:
        check(Bool(result) and result.value().is_err(), "cleanup failure survives cancellation")
        var failure = result.take()._take_err()
        check(failure.canceled and failure.errors.first() == 42, "full failure retains cancellation and exact error")
    else:
        check(not result, "successful withdrawal preserves cancellation-only")


def main() raises:
    withdrawal_case(False)
    withdrawal_case(True)
    print("instant cleanup: masked withdrawal past Int.MAX, retained captures, late completion rejection, exact failure")
