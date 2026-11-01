"""Per-element cost of concurrent traversal.

Compares the dedicated loop (`traverse[AsyncPar[Int]]`, one fiber per element
through `_StartParCollect`) against the fallback that needs no new machine
(an applicative whose `map2_lazy` is `both`, folded once per element as the
default `_loop` folds: two fibers and one pair leaf per element, nesting
`both` once per element), against a bare `start` per element followed by a
`join` of each, and against sequential `traverse[Async[Int]]`. Every element
is `IO.pure`, so the times are the per-element overhead. Medians of six trials.
"""
from std.time import perf_counter_ns
from std.os import abort
from fp.algebra import traverse
from fp.callables import OnceUnary, Binary
from fp.functions import tupled
from fp.effects import Outcome
from fp.effects._async.engine import AsyncPar, Async
from fp.effects.async_runtime import IO, Fiber, run


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def element(var value: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(value)


@fieldwise_init
struct Append(Binary, Copyable):
    comptime First = List[Int]
    comptime Second = Int
    comptime Out = List[Int]
    comptime Error = Never

    def call(self, var acc: List[Int], var value: Int) -> List[Int]:
        acc.append(value)
        return acc^


def fallback(n: Int) -> IO[List[Int], Int]:
    var acc = IO[List[Int], Int].pure(List[Int]())
    for index in range(n):
        acc = acc^.both(element(index)).map(tupled(Append()))
    return acc^


@fieldwise_init
struct Keep(OnceUnary):
    var fibers: List[Fiber[Int, Int]]
    var index: Int
    var n: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[List[Int], Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[List[Int], Int]:
        var fibers = self.fibers^
        fibers.append(fiber^)
        if self.index + 1 < self.n:
            return element(self.index + 1).start().flat_map(Keep(fibers^, self.index + 1, self.n))
        fibers.reverse()
        return _join_next(fibers^, List[Int](capacity=self.n))


def _join_next(var fibers: List[Fiber[Int, Int]], var values: List[Int]) -> IO[List[Int], Int]:
    if not len(fibers):
        return IO[List[Int], Int].pure(values^)
    var fiber = fibers.pop()
    return fiber^.join_with_never().flat_map(JoinNext(fibers^, values^))


@fieldwise_init
struct JoinNext(OnceUnary):
    var fibers: List[Fiber[Int, Int]]
    var values: List[Int]
    comptime Arg = Int
    comptime Out = IO[List[Int], Int]

    def call_once(deinit self, var value: Int) -> IO[List[Int], Int]:
        var values = self.values^
        values.append(value)
        return _join_next(self.fibers^, values^)


def start_join(n: Int) -> IO[List[Int], Int]:
    return element(0).start().flat_map(Keep(List[Fiber[Int, Int]](), 0, n))


def source(n: Int) -> List[Int]:
    var values = List[Int](capacity=n)
    for index in range(n):
        values.append(index)
    return values^


def expect(var outcome: Outcome[List[Int], Int], n: Int):
    check(Bool(outcome) and outcome.value().is_ok(), "success")
    var values = outcome.take()._take_ok()
    check(len(values) == n and (n == 0 or values[n - 1] == n - 1), "values in order")


def time_case(kind: Int, n: Int, reps: Int) -> Float64:
    var start = perf_counter_ns()
    for _ in range(reps):
        if kind == 0:
            expect(run(traverse[AsyncPar[Int]](source(n), element)), n)
        elif kind == 1:
            expect(run(fallback(n)), n)
        elif kind == 2:
            expect(run(start_join(n)), n)
        else:
            expect(run(traverse[Async[Int]](source(n), element)), n)
    var elapsed = perf_counter_ns() - start
    return Float64(elapsed) / Float64(reps * n)


def median(var values: List[Float64]) -> Float64:
    sort(values)
    var middle = len(values) // 2
    if len(values) % 2:
        return values[middle]
    return (values[middle - 1] + values[middle]) / 2


def main():
    # Cases alternate within each trial, so drift on a shared host affects
    # every case alike; the fallback nests one fiber per element.
    var names = ["dedicated loop", "fallback (both fold)", "bare start+join", "sequential traverse"]
    var sizes = [10, 1000, 100000]
    var reps = [2000, 40, 1]
    comptime TRIALS = 10
    for size_index in range(len(sizes)):
        var trials = List[List[Float64]]()
        for _ in range(4):
            trials.append(List[Float64]())
        for _ in range(TRIALS):
            for kind in range(4):
                trials[kind].append(time_case(kind, sizes[size_index], reps[size_index]))
        var bare = median(trials[2].copy())
        for kind in range(4):
            var value = median(trials[kind].copy())
            print(names[kind], "n =", sizes[size_index], ":", Int(value), "ns/element,", value / bare, "x bare")
