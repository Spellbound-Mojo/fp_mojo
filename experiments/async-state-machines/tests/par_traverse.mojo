"""Concurrent traversal: 100 sleeps of 50 ms overlap, on virtual time and on the system clock."""
from std.os import abort
from std.time import perf_counter_ns
from fp.callables import Unary, OnceUnary
from fp.algebra import par_traverse
from fp.effects import Outcome
from fp.effects.async_runtime import IO, Duration, Instant, TestControl, run


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def ms(value: Int) -> Duration:
    try:
        return Duration.milliseconds(value)
    except:
        abort("a valid duration")


@fieldwise_init
struct Value(OnceUnary):
    var value: Int
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        return self.value


def nap(var index: Int) -> IO[Int, Int]:
    return IO[NoneType, Int].sleep(ms(50)).map(Value(index * 3))


def indices(n: Int) -> List[Int]:
    var values = List[Int]()
    for index in range(n):
        values.append(index)
    return values^


def in_order(var outcome: Outcome[List[Int], Int], n: Int):
    check(Bool(outcome) and outcome.value().is_ok(), "the traversal succeeds")
    var values = outcome.take()._take_ok()
    check(len(values) == n, "one result per element")
    for index in range(n):
        check(values[index] == index * 3, "results keep source order")


def virtual_time():
    var control = TestControl(par_traverse(indices(100), nap))
    control.tick_all()
    check(control.is_completed(), "the traversal completes")
    check(control.now().since(Instant()).to_nanoseconds() == 50_000_000, "100 sleeps of 50 ms complete at virtual 50 ms")
    in_order(control^.results(), 100)


def system_clock():
    var start = perf_counter_ns()
    var outcome = run(par_traverse(indices(100), nap))
    var elapsed = perf_counter_ns() - start
    in_order(outcome^, 100)
    # The sleeps overlap: in sequence they would take 5 s. The bound leaves room
    # for 100 fiber starts at O0 on a shared host; 60 ms failed 6 of 20 runs.
    check(elapsed < 250_000_000, String("100 sleeps of 50 ms complete within 250 ms on the system clock, took ", elapsed, " ns"))


def empty_source():
    var control = TestControl(par_traverse(List[Int](), nap))
    control.tick()
    check(control.is_completed(), "an empty source completes at once")
    in_order(control^.results(), 0)


def main():
    virtual_time()
    system_clock()
    empty_source()
    print("par_traverse: 100 sleeps of 50 ms overlap on virtual and system time, results in source order")
