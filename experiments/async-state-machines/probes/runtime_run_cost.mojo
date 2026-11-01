"""The caller's wait in `Runtime.run` on a work-stealing runtime (build at -O3; not qualified).

`Runtime.run` submits its root to the runtime's workers and waits for it on
the calling thread, which is not a worker. Each case uses one 4-worker
runtime and prints the median of `ROUNDS` round medians with the range of
round medians in brackets:

- `pure`: `runtime.run(IO.pure(i))`, per run, in nanoseconds.
- `join`: a program that starts a child and joins it, per run.
- `cede`: a program that cedes 10 times, per run.
- `free`: the free `run(IO.pure(i))` on a per-call pool, for reference.
- `pure_ct`: `runtime.run(IO.pure(i))` on a current-thread runtime, per run.
- `sleep`: a program that sleeps 1 ms; the run's lateness past 1 ms, in
  microseconds.
- `cpu_sleep`: process CPU per run of a program that sleeps 5 ms, in
  microseconds: what a long run costs the waiting caller.
- `idle`: process CPU used by one run that sleeps 2 s, in microseconds.

The same file builds against `nightly`. Usage: `runtime_run_cost [case]`;
all cases by default. Compare only runs taken back to back.
"""
from std.os import abort
from std.sys import argv
from std.time import perf_counter_ns
from fp.callables import OnceUnary
from fp.effects import Outcome
from fp.effects.async_runtime import IO, Fiber, Duration, IORuntimeConfig, Profile, Runtime, run
from fp._internal.os import getrusage, RUSAGE_SELF

comptime ROUNDS = 6
comptime WORKERS = 4


def check(condition: Bool, message: String):
    if not condition:
        abort(String("runtime_run_cost: ", message))


def pooled() -> IORuntimeConfig:
    var settings = IORuntimeConfig()
    try:
        settings.profile = Profile.work_stealing(WORKERS)
    except:
        abort("runtime_run_cost: a valid worker count")
    return settings^


def ok(var outcome: Outcome[Int, Int]) -> Int:
    check(Bool(outcome) and outcome.value().is_ok(), "the program succeeds")
    return outcome.take()._take_ok()


def summary(var rounds: List[Float64]) -> String:
    sort(rounds)
    return String(rounds[len(rounds) // 2], " [", rounds[0], "-", rounds[len(rounds) - 1], "]")


def duration(nanoseconds: Int) -> Duration:
    try:
        return Duration.nanoseconds(nanoseconds)
    except:
        abort("runtime_run_cost: a valid duration")


def cpu_ns() -> Int:
    try:
        var usage = getrusage(RUSAGE_SELF)
        return usage.user_nanoseconds + usage.system_nanoseconds
    except:
        abort("runtime_run_cost: getrusage")


@fieldwise_init
struct Const(OnceUnary):
    var value: Int
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        return self.value


struct JoinValue(OnceUnary, Defaultable):
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def __init__(out self):
        pass

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join_with(IO[Int, Int].pure(0))


def join_program(value: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(value).start().flat_map(JoinValue())


def cede_program(value: Int) -> IO[Int, Int]:
    var program = IO[NoneType, Int].cede()
    for _ in range(9):
        program = program^.flat_map(CedeAgain())
    return program^.map(Const(value))


struct CedeAgain(OnceUnary, Defaultable):
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def __init__(out self):
        pass

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        return IO[NoneType, Int].cede()


def per_run(runtime: Runtime, kind: String, count: Int) -> Float64:
    var start = perf_counter_ns()
    for i in range(count):
        if kind == "pure":
            check(ok(runtime.run(IO[Int, Int].pure(i))) == i, "pure value")
        elif kind == "join":
            check(ok(runtime.run(join_program(i))) == i, "joined value")
        elif kind == "cede":
            check(ok(runtime.run(cede_program(i))) == i, "ceded value")
        elif kind == "pure_ct":
            check(ok(runtime.run(IO[Int, Int].pure(i))) == i, "current-thread value")
        else:
            check(ok(run(IO[Int, Int].pure(i), pooled())) == i, "free run value")
    return Float64(Int(perf_counter_ns() - start)) / Float64(count)


def lateness(runtime: Runtime) -> Float64:
    comptime count = 50
    var start = perf_counter_ns()
    for _ in range(count):
        _ = ok(runtime.run(IO[NoneType, Int].sleep(duration(1_000_000)).map(Const(0))))
    var elapsed = Float64(Int(perf_counter_ns() - start)) / Float64(count)
    return (elapsed - 1_000_000.0) / 1_000.0


def cpu_sleep(runtime: Runtime) -> Float64:
    comptime count = 40
    var before = cpu_ns()
    for _ in range(count):
        _ = ok(runtime.run(IO[NoneType, Int].sleep(duration(5_000_000)).map(Const(0))))
    return Float64(cpu_ns() - before) / Float64(count) / 1_000.0


def idle(runtime: Runtime) -> Float64:
    var before = cpu_ns()
    _ = ok(runtime.run(IO[NoneType, Int].sleep(duration(2_000_000_000)).map(Const(0))))
    return Float64(cpu_ns() - before) / 1_000.0


def measure(runtime: Runtime, name: String, selected: String):
    if selected != "all" and selected != name:
        return
    var rounds = List[Float64]()
    var count = 2_000 if name == "pure" or name == "free" or name == "pure_ct" else 1_000
    for _ in range(ROUNDS if name != "idle" else 3):
        if name == "sleep":
            rounds.append(lateness(runtime))
        elif name == "cpu_sleep":
            rounds.append(cpu_sleep(runtime))
        elif name == "idle":
            rounds.append(idle(runtime))
        else:
            rounds.append(per_run(runtime, name, count))
    print(name, summary(rounds^))


def main():
    var selected = String("all")
    var arguments = argv()
    if len(arguments) > 1:
        selected = String(arguments[1])
    var runtime: Runtime
    try:
        runtime = Runtime(pooled())
    except:
        abort("runtime_run_cost: the runtime starts")
    # Warm the workers and the caller's path once.
    _ = per_run(runtime, "pure", 200)
    for name in ["pure", "join", "cede", "free", "sleep", "cpu_sleep", "idle"]:
        measure(runtime, name, selected)
    var settings = IORuntimeConfig()
    settings.profile = Profile.current_thread()
    var single: Runtime
    try:
        single = Runtime(settings)
    except:
        abort("runtime_run_cost: the current-thread runtime starts")
    measure(single, "pure_ct", selected)
