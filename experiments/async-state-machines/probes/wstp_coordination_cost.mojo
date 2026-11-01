"""Contention on held coordination locks under the work-stealing pool (build at -O3; not qualified).

`FIBERS` fibers each apply `UPDATES` updates to one shared `Ref[Int]`, whose
callback spins `spin` rounds while the Ref's lock is held. An async attempt
that finds the lock held returns a runnable wait and is rescheduled at once
(`_attempt` in `_async/attempts.mojo`), so a long callback can make other
workers busy-poll. The probe prints, per worker count and callback length,
the wall time per update and the ratio of process CPU time to wall time: a
serialized lock with waiters that sleep keeps the ratio near 1, and workers
that busy-poll push it toward the worker count.

Medians of `TRIALS` runs. Compare only runs taken back to back.
"""
from std.memory import ArcPointer
from std.os import abort
from std.time import perf_counter_ns
from fp.callables import OnceUnary
from fp.effects import CancellationToken, Outcome
from fp.effects.async_runtime import IO, Fiber, IORuntimeConfig, Ref
from fp.effects._async.pool import _run_pooled
from fp._internal.os import getrusage, RUSAGE_SELF

comptime FIBERS = 16
comptime UPDATES = 200
comptime TRIALS = 5


@fieldwise_init
struct Add(OnceUnary):
    var spin: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        var x = UInt64(value) + 1
        for _ in range(self.spin):
            x ^= x << 13
            x ^= x >> 7
            x ^= x << 17
        return value + 1 + Int(x == 0x5EED5EED)


@fieldwise_init
struct Loop(OnceUnary):
    var left: Int
    var cell: Ref[Int]
    var spin: Int
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(0)
        return self.cell.update[Int](Add(self.spin)).flat_map(Self(self.left - 1, self.cell.copy(), self.spin))


def worker(cell: Ref[Int], spin: Int) -> IO[Int, Int]:
    return IO[NoneType, Int].pure(None).flat_map(Loop(UPDATES, cell.copy(), spin))


@fieldwise_init
struct StartRest(OnceUnary):
    var next: Int
    var fibers: List[Fiber[Int, Int]]
    var cell: Ref[Int]
    var spin: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        self.fibers.append(fiber^)
        if self.next == FIBERS:
            return join_all(self.fibers^)
        return worker(self.cell, self.spin).start().flat_map(Self(self.next + 1, self.fibers^, self.cell.copy(), self.spin))


def join_all(var fibers: List[Fiber[Int, Int]]) -> IO[Int, Int]:
    if not len(fibers):
        return IO[Int, Int].pure(0)
    var first = fibers.pop(0)
    return first^.join().flat_map(JoinNext(fibers^))


@fieldwise_init
struct JoinNext(OnceUnary):
    var rest: List[Fiber[Int, Int]]
    comptime Arg = Outcome[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> IO[Int, Int]:
        return join_all(self.rest^)


def cpu_ns() -> Int:
    try:
        var usage = getrusage(RUSAGE_SELF)
        return usage.user_nanoseconds + usage.system_nanoseconds
    except:
        abort("getrusage")


def median(var values: List[Int]) -> Int:
    sort(values)
    return values[len(values) // 2]


def measure(workers: Int, spin: Int):
    var walls = List[Int]()
    var ratios = List[Int]()
    for _ in range(TRIALS):
        var cell: Ref[Int]
        try:
            cell = Ref[Int](0)
        except:
            abort("ref")
        var program = worker(cell, spin).start().flat_map(StartRest(1, List[Fiber[Int, Int]](), cell.copy(), spin))
        var cpu = cpu_ns()
        var start = perf_counter_ns()
        _ = _run_pooled(program^, CancellationToken(), IORuntimeConfig(), workers)
        var wall = Int(perf_counter_ns() - start)
        cpu = cpu_ns() - cpu
        walls.append(wall // (FIBERS * UPDATES))
        ratios.append(cpu * 100 // max(wall, 1))
    print("workers", workers, "spin", spin, "ns_per_update", median(walls^), "cpu_per_wall_percent", median(ratios^))


def main():
    for spin in [0, 2_000, 20_000]:
        for workers in [1, 4]:
            measure(workers, spin)
