"""IO sequencing costs comparable with the first iterative IO engine (build at -O3; not qualified).

Uses only API that existed at commit `e4cad044`: `IO.pure`, `map`
and `flat_map` with library callables, the free `run` and `fold_outcome`. The
same file therefore builds at that commit and on `nightly`, under either
`-D FP_ASYNC_PROFILE`. Cases, each the median of 9 samples after a warm-up,
in nanoseconds per step:

- `loop`: a recursion through `flat_map` that builds each next step when it
  runs, 1,000,000 steps.
- `chain`: a runtime-built chain of 100,000 `map` stages, built, then run.
- `run`: a trivial `run(IO.pure(i))`, per run.

Usage: `foundation_compare [case] [steps]`; `rss` runs one `loop` of `steps`
steps and prints nothing else, for peak-RSS measurement under `/usr/bin/time`.
"""
from std.os import abort
from std.sys import argv
from std.time import perf_counter_ns
from fp.callables import OnceUnary
from fp.effects import EffectFailure, fold_outcome
from fp.effects.async_runtime import IO, run


def success(value: Int) -> Int:
    return value


def failure(var errors: EffectFailure[Int]) -> Int:
    abort("foundation_compare: the program failed")


def canceled() -> Int:
    abort("foundation_compare: the program was canceled")


@fieldwise_init
struct Loop(OnceUnary):
    var left: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(total)
        return IO[Int, Int].pure(total + 1).flat_map(Loop(self.left - 1))


@fieldwise_init
struct Plus(OnceUnary):
    var amount: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        return value + self.amount


@no_inline
def loop(steps: Int) -> Int:
    return fold_outcome(run(IO[Int, Int].pure(0).flat_map(Loop(steps))), success, failure, canceled)


@no_inline
def chain(stages: Int) -> Int:
    var program = IO[Int, Int].pure(0)
    for _ in range(stages):
        program = program^.map(Plus(1))
    return fold_outcome(run(program^), success, failure, canceled)


@no_inline
def trivial(count: Int) -> Int:
    var total = 0
    for i in range(count):
        total += fold_outcome(run(IO[Int, Int].pure(i)), success, failure, canceled)
    return total


def sample(kind: Int, size: Int) -> Float64:
    var start = perf_counter_ns()
    var value: Int
    if kind == 0:
        value = loop(size)
    elif kind == 1:
        value = chain(size)
    else:
        value = trivial(size)
    var elapsed = perf_counter_ns() - start
    var expected = size if kind < 2 else size * (size - 1) // 2
    if value != expected:
        abort("foundation_compare: wrong result")
    return Float64(elapsed) / Float64(size)


def measure(name: String, kind: Int, size: Int):
    _ = sample(kind, size)
    var samples = List[Float64]()
    for _ in range(9):
        samples.append(sample(kind, size))
    sort(samples)
    print(name, "ns per step: median", samples[4], "range", samples[0], "-", samples[8])


def main():
    var selected = String(argv()[1]) if len(argv()) > 1 else String("all")
    if selected == "rss":
        var steps: Int
        try:
            steps = Int(String(argv()[2]))
        except:
            abort("foundation_compare: rss <steps>")
        if loop(steps) != steps:
            abort("foundation_compare: wrong result")
        return
    if selected == "all" or selected == "loop":
        measure("loop", 0, 1_000_000)
    if selected == "all" or selected == "chain":
        measure("chain", 1, 100_000)
    if selected == "all" or selected == "run":
        measure("run", 2, 2_000)
