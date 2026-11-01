"""Concurrent traversal failures: stop the rest, finalize once, report in element order, drain on cancellation.

Every timing outcome is forced on TestControl's virtual clock: the failing
element fails before any other element can finish, so no assertion depends
on which side of a race a schedule reaches.
"""
from std.memory import ArcPointer
from std.os import abort
from fp.callables import Unary
from fp.effects import Outcome
from fp.algebra import par_traverse
from fp.effects.async_runtime import IO, Ref, Duration, Instant, TestControl, IORuntimeConfig, run


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def ms(value: Int) -> Duration:
    try:
        return Duration.milliseconds(value)
    except:
        abort("a valid duration")


def inc(var count: Int) -> Int:
    return count + 1


def errors_of(var outcome: Outcome[List[Int], Int]) -> Tuple[List[Int], Bool]:
    if not outcome or outcome.value().is_ok():
        abort("expected a failure")
    var failure = outcome.take()._take_err()
    var canceled = failure.canceled
    return (failure^.into_errors().into_list(), canceled)


@fieldwise_init
struct Value(Unary, Copyable):
    var value: Int
    comptime Arg = NoneType
    comptime Out = Int
    comptime Error = Never

    def call(self, var unit: NoneType) -> Int:
        return self.value


@fieldwise_init
struct Element(Unary, Copyable):
    """Element 7 fails at once and element 2's finalizer fails; the rest sleep 100 ms.

    Every element except 7 counts its finalizer, and the callback counts its calls.
    """
    var finalized: Ref[Int]
    var calls: ArcPointer[Int]
    var raising_at: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]
    comptime Error = Int

    def call(self, var index: Int) raises Int -> IO[Int, Int]:
        self.calls[] += 1
        if index == self.raising_at:
            raise index
        if index == 7:
            return IO[Int, Int].raise_error(7)
        var body = IO[NoneType, Int].sleep(ms(100)).map(Value(index)).guarantee(self.finalized.update[Int](inc))
        if index == 2:
            return body^.guarantee(IO[NoneType, Int].raise_error(2))
        return body^


def indices(n: Int) -> List[Int]:
    var values = List[Int]()
    for index in range(n):
        values.append(index)
    return values^


def count_of(cell: Ref[Int]) -> Int:
    var outcome = run(cell.get[Int]())
    return outcome.take()._take_ok()


def since_zero(now: Instant) -> Int:
    return now.since(Instant()).to_nanoseconds()


def failure_stops_the_rest() raises:
    var finalized = Ref[Int](0)
    var calls = ArcPointer[Int](0)
    var control = TestControl(par_traverse(indices(10), Element(finalized.copy(), calls.copy(), -1)))
    control.tick_all()
    check(control.is_completed(), "the traversal completes")
    check(since_zero(control.now()) == 0, "the failure stops the sleeping elements at once")
    var seen = errors_of(control^.results())
    check(len(seen[0]) == 2 and seen[0][0] == 2 and seen[0][1] == 7, "errors in element order, not in time order")
    check(seen[1], "the stopped elements record cancellation")
    check(count_of(finalized) == 9, "every finalizer runs exactly once")
    check(calls[] == 10, "the callback runs once per element")


def callback_error_stops_pulling() raises:
    var finalized = Ref[Int](0)
    var calls = ArcPointer[Int](0)
    var control = TestControl(par_traverse(indices(20), Element(finalized.copy(), calls.copy(), 5)))
    control.tick_all()
    var seen = errors_of(control^.results())
    check(calls[] == 6, "elements after the failing callback are never pulled")
    # Elements 0 to 4 start in the same step as the failing callback, so they
    # are stopped before their first poll: like a fiber canceled before it
    # runs, they run no finalizer and report only cancellation.
    check(len(seen[0]) == 1 and seen[0][0] == 5 and seen[1], "the callback's error, with the stopped elements' cancellation")
    check(count_of(finalized) == 0, "elements stopped before they ran run no finalizer")


def cancel_drains_every_child() raises:
    var finalized = Ref[Int](0)
    var calls = ArcPointer[Int](0)
    var sleepers = List[Int]()
    for index in range(10):
        if index != 2 and index != 7:
            sleepers.append(index)
    var all_sleep = Element(finalized.copy(), calls.copy(), -1)
    var control = TestControl(par_traverse(sleepers^, all_sleep^))
    control.tick()
    check(not control.is_completed(), "every element sleeps")
    control.request_cancel()
    control.tick_all()
    check(control.is_completed() and since_zero(control.now()) == 0, "cancellation completes without waiting")
    var outcome = control^.results()
    check(not outcome, "the traversal is canceled")
    check(count_of(finalized) == 8, "canceling the parent drains every child")


@fieldwise_init
struct Yielding(Unary, Copyable):
    """Yield once, then succeed with the index, or fail for element `failing`."""
    var failing: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]
    comptime Error = Never

    def call(self, var index: Int) -> IO[Int, Int]:
        if index == self.failing:
            return IO[NoneType, Int].cede().map(Value(index)).flat_map(Fail(index))
        return IO[NoneType, Int].cede().map(Value(index * 10))


@fieldwise_init
struct Fail(Unary, Copyable):
    var error: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]
    comptime Error = Never

    def call(self, var ignored: Int) -> IO[Int, Int]:
        return IO[Int, Int].raise_error(self.error)


def late_announcements() raises:
    """A child announces from its last finalizer, before its record publishes.

    With a small interpreter budget per root poll, a child's announcement and
    its record's completion fall into different polls, so the parent finds
    announced records that have not completed and waits on their own signals.
    On TestControl every threshold below gives the same schedule each run; at
    the time of writing, instrumentation showed late records for every
    threshold here except 7 (all four elements at threshold 4).
    """
    for threshold in range(1, 12):
        var control = TestControl(par_traverse(indices(4), Yielding(-1)), IORuntimeConfig(1, threshold))
        control.tick_all()
        var outcome = control^.results()
        check(Bool(outcome) and outcome.value().is_ok(), "late records still complete the traversal")
        var values = outcome.take()._take_ok()
        for index in range(4):
            check(values[index] == index * 10, "late records keep source order")
        var failing = TestControl(par_traverse(indices(4), Yielding(2)), IORuntimeConfig(1, threshold))
        failing.tick_all()
        var seen = errors_of(failing^.results())
        check(len(seen[0]) == 1 and seen[0][0] == 2, "a late failing record still stops the rest and reports its error")


def main() raises:
    failure_stops_the_rest()
    callback_error_stops_pulling()
    cancel_drains_every_child()
    late_announcements()
    print("par_traverse failure: the first failure stops the rest; errors in element order; finalizers once; cancellation drains")
