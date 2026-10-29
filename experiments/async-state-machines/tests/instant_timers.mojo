from fp.effects import CancellationToken
from fp.effects._async.application import sleep, both
from fp.effects._async.host import Clock, Driver
from fp.effects._async.time import Duration, Instant
from std.os import abort


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def advance(clock: Clock, point: Instant):
    try:
        clock.advance_to(point)
    except error:
        abort("valid clock advance rejected")


def main() raises:
    var clock = Clock.manual(Int.MAX)
    var tick = Duration.nanoseconds(7)
    var start = clock.now()
    var driver = Driver(sleep[Int](tick), CancellationToken(), clock)
    var pending = driver.poll()
    check(not pending.completed and not pending.runnable and pending.deadline.value() == start + tick, "entry past Int.MAX keeps its live deadline")
    advance(clock, pending.deadline.value())
    while not driver.poll().completed:
        pass
    var result = driver^.finish()
    check(Bool(result) and result.value().is_ok(), "timer past Int.MAX completes normally")

    var leap = Duration.nanoseconds(1000000000000000000)
    var base = start.copy()
    for _ in range(9):
        base = base + leap
    advance(clock, base)
    var near = Duration.nanoseconds(100000000000000000)
    var far = Duration.nanoseconds(900000000000000000)
    var group = Driver(both(sleep[Int](near), sleep[Int](far)), CancellationToken(), clock)
    var first = group.poll()
    check(first.deadline.value() == base + near, "heap selects the earlier low-word deadline")
    advance(clock, first.deadline.value())
    var second = group.poll()
    check(not second.completed and second.deadline.value() == base + far, "heap retains later deadline across word carry")
    advance(clock, second.deadline.value())
    while not group.poll().completed:
        pass
    var joined = group^.finish()
    check(Bool(joined) and joined.value().is_ok(), "both timers drain across the carry")
    print("instant timers: entry past Int.MAX, ordered deadlines across word carry, complete child draining")
