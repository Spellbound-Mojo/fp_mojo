"""Gate timing for `run` parking in the root's poller: a trivial `run()` (build at -O3; not qualified).

Loops `run(IO[Int, Int].pure(i))` 20,000 times per trial and prints the median
per run over 9 trials, with the min-max spread. The same file builds against
`nightly` and the change under test: it uses only API both share. Compare only runs taken back to back.
"""
from std.os import abort
from std.time import perf_counter_ns
from fp.effects.async_runtime import IO, run

comptime COUNT = 20_000
comptime TRIALS = 9


def trial() -> Float64:
    var total = 0
    var start = perf_counter_ns()
    for i in range(COUNT):
        var outcome = run(IO[Int, Int].pure(i))
        total += outcome.take()._take_ok()
    var elapsed = Float64(Int(perf_counter_ns() - start))
    if total != COUNT * (COUNT - 1) // 2:
        abort("every run returns its value")
    return elapsed / Float64(COUNT)


def main():
    _ = trial()
    var samples = List[Float64]()
    for _ in range(TRIALS):
        samples.append(trial())
    sort(samples)
    print("run_trivial median_ns=" + String(Int(samples[TRIALS // 2])) + " min=" + String(Int(samples[0])) + " max=" + String(Int(samples[TRIALS - 1])))
