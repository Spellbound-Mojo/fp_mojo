from fp._internal.time import Duration, Instant
from fp.effects._async.host import Clock
from std.os import abort


def check(condition: Bool):
    if not condition:
        abort("opaque instant arithmetic or shared clock failed")


def main() raises:
    var clock = Clock.manual(Int.MAX)
    var shared = clock.copy()
    var span = Duration.nanoseconds(1000000000000000000)
    var start = clock.now()
    var current = start.copy()
    for _ in range(10):
        var next = current + span
        check(next > current and current < next and next >= current and current <= next and next != current)
        current = next^
    check(current > start and current == current.copy())
    shared.advance_to(current)
    check(clock.now() == current)
    var rejected = 0
    try:
        clock.advance_to(start)
    except error:
        rejected += 1
    check(shared.now() == current)
    try:
        Clock().advance_to(current)
    except error:
        rejected += 1
    try:
        _ = Clock.manual(-1)
    except error:
        rejected += 1
    check(rejected == 3)
    check(current.after(Duration()) == current)
    print("instant: carry across native bounds, total ordering, shared checked clock advance")
