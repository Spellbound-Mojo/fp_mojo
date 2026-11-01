"""Regression gates for concurrent traversal: both, race, a fiber pair, sequential traverse with IO, and a trivial run.

Uses only operations that predate concurrent traversal, so the same file
builds against the nightly baseline. Prints one median per case, in ns per
operation; run the two builds back to back.
"""
from std.time import perf_counter_ns
from std.os import abort
from fp.algebra import traverse
from fp.callables import OnceUnary
from fp.effects import Outcome
from fp.effects.async_runtime import IO, Async, Fiber, RaceResult, run


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


@fieldwise_init
struct Sum(OnceUnary):
    comptime Arg = Tuple[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var pair: Tuple[Int, Int]) -> Int:
        return pair[0] + pair[1]


@fieldwise_init
struct Pick(OnceUnary):
    comptime Arg = RaceResult[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var result: RaceResult[Int, Int]) -> Int:
        return 1


@fieldwise_init
struct StartRight(OnceUnary):
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var left: Fiber[Int, Int]) -> IO[Int, Int]:
        return IO[Int, Int].pure(2).start().flat_map(JoinLeft(left^))


@fieldwise_init
struct JoinLeft(OnceUnary):
    var left: Fiber[Int, Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var right: Fiber[Int, Int]) -> IO[Int, Int]:
        return self.left^.join_with_never().flat_map(JoinRight(right^))


@fieldwise_init
struct JoinRight(OnceUnary):
    var right: Fiber[Int, Int]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var first: Int) -> IO[Int, Int]:
        return self.right^.join_with_never()


def element(var value: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(value)


def ok[T: Movable & Deinitable](var outcome: Outcome[T, Int]):
    check(Bool(outcome) and outcome.value().is_ok(), "success")


def time_case(kind: Int, reps: Int) -> Float64:
    var values = List[Int](capacity=1000)
    for index in range(1000):
        values.append(index)
    var start = perf_counter_ns()
    for _ in range(reps):
        if kind == 0:
            ok(run(IO[Int, Int].pure(1).both(IO[Int, Int].pure(2)).map(Sum())))
        elif kind == 1:
            ok(run(IO[Int, Int].pure(1).race(IO[Int, Int].pure(2)).map(Pick())))
        elif kind == 2:
            ok(run(IO[Int, Int].pure(1).start().flat_map(StartRight())))
        elif kind == 3:
            ok(run(traverse[Async[Int]](values.copy(), element)))
        else:
            ok(run(IO[Int, Int].pure(1)))
    return Float64(perf_counter_ns() - start) / Float64(reps)


def median(var values: List[Float64]) -> Float64:
    sort(values)
    var middle = len(values) // 2
    if len(values) % 2:
        return values[middle]
    return (values[middle - 1] + values[middle]) / 2


def main():
    var names = ["both", "race", "fiber pair", "sequential traverse of 1,000 IO", "trivial run"]
    var reps = [20000, 20000, 20000, 400, 50000]
    var trials = List[List[Float64]]()
    for _ in range(5):
        trials.append(List[Float64]())
    for _ in range(8):
        for kind in range(5):
            trials[kind].append(time_case(kind, reps[kind]))
    for kind in range(5):
        print(names[kind], ":", Int(median(trials[kind].copy())), "ns")
