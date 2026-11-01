"""Diagnostic timings: the leaf child pair against a pair built from fibers."""
from std.time import perf_counter_ns
from std.os import abort
from fp.callables import OnceUnary
from fp.effects import Outcome
from fp.effects.async_runtime import IO, Fiber, run


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def child(value: Int, yields: Bool) -> IO[Int, Int]:
    if yields:
        return IO[NoneType, Int].cede().map(Const(value))
    return IO[Int, Int].pure(value)


@fieldwise_init
struct Const(OnceUnary):
    var value: Int
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        return self.value


@fieldwise_init
struct Sum(OnceUnary):
    comptime Arg = Tuple[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var pair: Tuple[Int, Int]) -> Int:
        return pair[0] + pair[1]


def leaf_pair(yields: Bool) -> IO[Int, Int]:
    return child(1, yields).both(child(2, yields)).map(Sum())


@fieldwise_init
struct StartRight(OnceUnary):
    var yields: Bool
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var left: Fiber[Int, Int]) -> IO[Int, Int]:
        return child(2, self.yields).start().flat_map(JoinLeft(left^))


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
        return self.right^.join_with_never().map(Plus(first))


@fieldwise_init
struct Plus(OnceUnary):
    var base: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        return self.base + value


def fiber_pair(yields: Bool) -> IO[Int, Int]:
    return child(1, yields).start().flat_map(StartRight(yields))


@fieldwise_init
struct Repeat[fibers: Bool](OnceUnary):
    """Run `left` more pairs in sequence inside one root, summing their results."""
    var left: Int
    var yields: Bool
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(total)
        var pair: IO[Int, Int]
        comptime if Self.fibers:
            pair = fiber_pair(self.yields)
        else:
            pair = leaf_pair(self.yields)
        return pair^.map(Plus(total)).flat_map(Repeat[Self.fibers](self.left - 1, self.yields))


def timed[fibers: Bool](count: Int, yields: Bool) -> Int:
    var start = perf_counter_ns()
    var outcome = run(IO[Int, Int].pure(0).flat_map(Repeat[fibers](count, yields)))
    var elapsed = Int(perf_counter_ns() - start)
    check(Bool(outcome) and outcome.value().is_ok() and outcome.take()._take_ok() == 3 * count, "every pair sums both children")
    return elapsed


def main():
    comptime count = 100_000
    for yields in range(2):
        _ = timed[False](1000, Bool(yields))
        _ = timed[True](1000, Bool(yields))
        for sample in range(5):
            var leaf = timed[False](count, Bool(yields))
            var fiber = timed[True](count, Bool(yields))
            print("pair", "yields=" + String(yields), "sample=" + String(sample),
                  "leaf_ns_per_pair=" + String(leaf // count), "fiber_ns_per_pair=" + String(fiber // count))
