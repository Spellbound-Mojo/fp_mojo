"""Allocations and time per IO frame, fiber start, completion and root (for the frame-pooling evaluation).

Run with the allocation counter preloaded (`alloc_counter.c`, whose
docstring has the commands); without it the counts read -1. Programs run
through one `Runtime` on the profile `IORuntimeConfig()` selects (`-D
FP_ASYNC_PROFILE`). For every case the probe prints, per operation, the Mojo
heap allocations, the frees, the bytes allocated, and the median wall time
of `SAMPLES` runs. Counts are process-wide, so on the pool they include
whatever the workers allocate while the program runs.

`storage_cost sites` instead prints the allocation call sites of one fiber
start/join cycle, one root and one callback completion: per operation, the
count at each return address, as an offset into the binary for `addr2line
-f -C -e <binary>`.

`alloc pair` is the cost of one allocation and its free of 64 bytes through
the same heap, the most pooling could save per allocation it removes.
"""
from std.atomic import Atomic, Ordering
from std.ffi import external_call
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.sys import argv
from std.time import perf_counter_ns
from fp.algebra import par_traverse
from fp.callables import OnceThunk, OnceUnary, Unary
from fp.data import Ok, Result
from fp.effects import EffectFailure, Outcome
from fp.effects.async_runtime import IO, Completion, Fiber, IORuntimeConfig, Runtime

comptime SAMPLES = 5


def check(condition: Bool, message: String):
    if not condition:
        abort(String("storage_cost: ", message))


struct Counts(Copyable):
    var allocations: Int
    var frees: Int
    var bytes: Int

    def __init__(out self):
        var name = List[UInt8]()
        for byte in "fp_alloc_counts".as_bytes():
            name.append(byte)
        name.append(0)
        var address = external_call["dlsym", Int](Int(0), name.unsafe_ptr())
        if address == 0:
            self.allocations = -1
            self.frees = -1
            self.bytes = -1
            return
        var words = Pointer[Atomic[Int], MutUntrackedOrigin](unsafe_from_address=address)
        self.allocations = words[unsafe_offset=0].load[ordering=Ordering.ACQUIRE]()
        self.frees = words[unsafe_offset=1].load[ordering=Ordering.ACQUIRE]()
        self.bytes = words[unsafe_offset=2].load[ordering=Ordering.ACQUIRE]()


def per(value: Int, count: Int) -> String:
    if value < 0:
        return String("-")
    var scaled = (value * 100) // count
    var text = String(scaled // 100) + "."
    var cents = scaled % 100
    if cents < 10:
        text += "0"
    return text + String(cents)


def report(label: String, before: Counts, after: Counts, count: Int, nanoseconds: Int):
    var allocations = after.allocations - before.allocations if before.allocations >= 0 else -1
    var frees = after.frees - before.frees if before.frees >= 0 else -1
    var bytes = after.bytes - before.bytes if before.bytes >= 0 else -1
    print(label, "| alloc", per(allocations, count), "| free", per(frees, count), "| bytes", per(bytes, count), "| ns", per(nanoseconds, count))


def median(mut values: List[Int]) -> Int:
    sort(values)
    return values[len(values) // 2]


# ===--- Programs ---=== #


@fieldwise_init
struct AddOne(OnceUnary):
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var value: Int) -> IO[Int, Int]:
        return IO[Int, Int].pure(value + 1)


@fieldwise_init
struct Increment(OnceUnary):
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        return value + 1


@fieldwise_init
struct Loop(OnceUnary):
    var limit: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var value: Int) -> IO[Int, Int]:
        if value == self.limit:
            return IO[Int, Int].pure(value)
        return IO[Int, Int].pure(value + 1).flat_map(Loop(self.limit))


def counted(n: Int) -> IO[Int, Int]:
    if n == 0:
        return IO[Int, Int].pure(0)
    return IO[Int, Int].defer(Counted(n)).map(Increment())


@fieldwise_init
struct Counted(OnceThunk):
    var n: Int
    comptime Out = IO[Int, Int]
    comptime Error = Never

    def call_once(deinit self) -> IO[Int, Int]:
        return counted(self.n - 1)


@fieldwise_init
struct Recover(OnceUnary):
    comptime Arg = EffectFailure[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var failure: EffectFailure[Int]) -> IO[Int, Int]:
        return IO[Int, Int].pure(0)


@fieldwise_init
struct Churn(OnceUnary):
    """Start a fiber, join it, and continue until `limit` cycles ran."""
    var limit: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var count: Int) -> IO[Int, Int]:
        if count == self.limit:
            return IO[Int, Int].pure(count)
        return IO[Int, Int].pure(count).start().flat_map(JoinNext(self.limit))


@fieldwise_init
struct JoinNext(OnceUnary):
    var limit: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join().flat_map(Next(self.limit))


@fieldwise_init
struct Next(OnceUnary):
    var limit: Int
    comptime Arg = Outcome[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> IO[Int, Int]:
        var count = outcome.take()._take_ok()
        return IO[Int, Int].pure(count + 1).flat_map(Churn(self.limit))


@fieldwise_init
struct StartMany(OnceUnary):
    """Start `remaining` more live fibers, then join them all."""
    var fibers: List[Fiber[Int, Int]]
    var remaining: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        if self.remaining == 0:
            return IO[Int, Int].pure(0).flat_map(JoinMany(self.fibers^))
        return IO[Int, Int].pure(1).start().flat_map(Keep(self.fibers^, self.remaining))


@fieldwise_init
struct Keep(OnceUnary):
    var fibers: List[Fiber[Int, Int]]
    var remaining: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        self.fibers.append(fiber^)
        return IO[Int, Int].pure(0).flat_map(StartMany(self.fibers^, self.remaining - 1))


@fieldwise_init
struct JoinMany(OnceUnary):
    var fibers: List[Fiber[Int, Int]]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        if not self.fibers:
            return IO[Int, Int].pure(total)
        var fiber = self.fibers.pop()
        return fiber^.join().flat_map(AddJoined(self.fibers^, total))


@fieldwise_init
struct AddJoined(OnceUnary):
    var fibers: List[Fiber[Int, Int]]
    var total: Int
    comptime Arg = Outcome[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> IO[Int, Int]:
        return IO[Int, Int].pure(self.total + outcome.take()._take_ok()).flat_map(JoinMany(self.fibers^))


@fieldwise_init
struct CompleteNow(OnceUnary):
    """A callback registration that completes at once, on the registering thread."""
    var value: Int
    comptime Arg = Completion[Int, Int]
    comptime Out = NoneType

    def call_once(deinit self, var completion: Completion[Int, Int]) -> NoneType:
        _ = completion.complete(Optional(Result[Int, EffectFailure[Int]](Ok(self.value))))
        return None


@fieldwise_init
struct Callbacks(OnceUnary):
    """Await `limit` callback completions in sequence."""
    var limit: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var count: Int) -> IO[Int, Int]:
        if count == self.limit:
            return IO[Int, Int].pure(count)
        return IO[Int, Int].async_(CompleteNow(count + 1)).flat_map(Callbacks(self.limit))


@fieldwise_init
struct Blocked(OnceThunk):
    var value: Int
    comptime Out = Int
    comptime Error = Never

    def call_once(deinit self) -> Int:
        return self.value


@fieldwise_init
struct Blocking(OnceUnary):
    var limit: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var count: Int) -> IO[Int, Int]:
        if count == self.limit:
            return IO[Int, Int].pure(count)
        return IO[Int, Int].blocking(Blocked(count + 1)).flat_map(Blocking(self.limit))


@fieldwise_init
struct Kid(Unary, Copyable):
    comptime Arg = Int
    comptime Out = IO[Int, Int]
    comptime Error = Never

    def call(self, var value: Int) -> IO[Int, Int]:
        return IO[Int, Int].pure(value)


@fieldwise_init
struct Count(OnceUnary):
    comptime Arg = List[Int]
    comptime Out = Int

    def call_once(deinit self, var values: List[Int]) -> Int:
        return len(values)


# ===--- Cases ---=== #


def binds(n: Int) -> IO[Int, Int]:
    var io = IO[Int, Int].pure(0)
    for _ in range(n):
        io = io^.flat_map(AddOne())
    return io^


def maps(n: Int) -> IO[Int, Int]:
    var io = IO[Int, Int].pure(0)
    for _ in range(n):
        io = io^.map(Increment())
    return io^


def finalizers(n: Int) -> IO[Int, Int]:
    var io = IO[Int, Int].pure(0)
    var unit: NoneType = None
    for _ in range(n):
        io = io^.guarantee(IO[NoneType, Int].pure(unit))
    return io^


def recoveries(n: Int) -> IO[Int, Int]:
    var io = IO[Int, Int].raise_error(1)
    for _ in range(n):
        io = io^.handle_error_with(Recover())
    return io^


def build_cost(label: String, kind: Int, n: Int):
    """Construction alone, then running what was built: two lines."""
    var runtime = make_runtime()
    var times = List[Int]()
    var build_times = List[Int]()
    var first_build = Counts()
    var first_run = Counts()
    var last = Counts()
    for sample in range(SAMPLES):
        var before = Counts()
        var started = perf_counter_ns()
        var io = binds(n) if kind == 0 else (maps(n) if kind == 1 else (finalizers(n) if kind == 2 else recoveries(n)))
        var built = perf_counter_ns()
        var middle = Counts()
        var outcome = runtime.run(io^)
        var ended = perf_counter_ns()
        check(Bool(outcome) and outcome.value().is_ok(), label + " succeeded")
        _ = outcome^
        var after = Counts()
        build_times.append(Int(built - started))
        times.append(Int(ended - built))
        if sample == 0:
            first_build = before.copy()
            first_run = middle.copy()
            last = after.copy()
    report(label + " build", first_build, first_run, n, median(build_times))
    report(label + " run", first_run, last, n, median(times))


def make_runtime() -> Runtime:
    try:
        return Runtime(IORuntimeConfig())
    except error:
        abort(String("storage_cost: ", error))


def run_cost(label: String, make: def(Int) thin -> IO[Int, Int], n: Int, ops: Int):
    """Build and run `make(n)` SAMPLES times; counts from the first run, per op."""
    var runtime = make_runtime()
    var times = List[Int]()
    var first = Counts()
    var after_first = Counts()
    for sample in range(SAMPLES):
        var before = Counts()
        var started = perf_counter_ns()
        var outcome = runtime.run(make(n))
        var ended = perf_counter_ns()
        check(Bool(outcome) and outcome.value().is_ok(), label + " succeeded")
        _ = outcome^
        var after = Counts()
        times.append(Int(ended - started))
        if sample == 0:
            first = before.copy()
            after_first = after.copy()
    report(label, first, after_first, ops, median(times))


def loop_program(n: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(0).flat_map(Loop(n))


def deferred_program(n: Int) -> IO[Int, Int]:
    return counted(n)


def churn_program(n: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(0).flat_map(Churn(n))


def many_program(n: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(0).flat_map(StartMany(List[Fiber[Int, Int]](), n))


def callback_program(n: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(0).flat_map(Callbacks(n))


def blocking_program(n: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(0).flat_map(Blocking(n))


def par_program(n: Int) -> IO[Int, Int]:
    var sources = List[Int](capacity=n)
    for i in range(n):
        sources.append(i)
    return par_traverse(sources^, Kid()).map(Count())


def pure_program(n: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(n)


def roots(label: String, n: Int):
    var runtime = make_runtime()
    for _ in range(10):
        _ = runtime.run(IO[Int, Int].pure(0))
    var times = List[Int]()
    var first = Counts()
    var after_first = Counts()
    for sample in range(SAMPLES):
        var before = Counts()
        var started = perf_counter_ns()
        for i in range(n):
            var outcome = runtime.run(IO[Int, Int].pure(i))
            _ = outcome^
        var ended = perf_counter_ns()
        var after = Counts()
        times.append(Int(ended - started))
        if sample == 0:
            first = before.copy()
            after_first = after.copy()
    report(label, first, after_first, n, median(times))


def alloc_pair(n: Int):
    """Allocate a batch of 64-byte blocks, then free them: the batch keeps O3 from eliding the pair."""
    comptime BATCH = 1_000
    var times = List[Int]()
    var slots = List[Int](length=BATCH, fill=0)
    var before = Counts()
    for _ in range(SAMPLES):
        var started = perf_counter_ns()
        for _ in range(n // BATCH):
            for i in range(BATCH):
                var p = unsafe_alloc[UInt8](64)
                p.unsafe_write(UInt8(i))
                slots[i] = Int(p)
            for i in range(BATCH):
                Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=slots[i]).unsafe_free()
        times.append(Int(perf_counter_ns() - started))
    var after = Counts()
    report("alloc pair (64 bytes)", before, after, n * SAMPLES, median(times) * SAMPLES)


comptime SITES = 4096


def site_table() -> List[Int]:
    """A copy of the preloaded counter's call-site table: address, count, ... ."""
    var name = List[UInt8]()
    for byte in "fp_alloc_sites".as_bytes():
        name.append(byte)
    name.append(0)
    var address = external_call["dlsym", Int](Int(0), name.unsafe_ptr())
    check(address != 0, "sites need the preloaded counter")
    var words = Pointer[Atomic[Int], MutUntrackedOrigin](unsafe_from_address=address)
    var table = List[Int](capacity=2 * SITES)
    for i in range(2 * SITES):
        table.append(words[unsafe_offset=i].load[ordering=Ordering.ACQUIRE]())
    return table^


def image_base(address: Int) -> Int:
    """The load address of the object holding `address`, from dladdr's Dl_info."""
    var info = List[Int](length=4, fill=0)
    if external_call["dladdr", Int32](address, info.unsafe_ptr()) == 0:
        return 0
    return info[1]


def print_sites(label: String, make: def(Int) thin -> IO[Int, Int], n: Int, roots: Int = 1):
    """Sites of `roots` runs of `make(n)`, per operation: `n` per run, or one per root when `n` is 1."""
    var runtime = make_runtime()
    _ = runtime.run(make(n))
    var before = site_table()
    for _ in range(roots):
        _ = runtime.run(make(n))
    var after = site_table()
    var operations = n * roots
    print("sites:", label)
    for i in range(SITES):
        var count = after[2 * i + 1] - before[2 * i + 1]
        if count > 0 and count >= operations // 2:
            var site = after[2 * i]
            var base = image_base(site)
            print("  ", per(count, operations), "per op at", hex(site - base), "in image", hex(base))


def main():
    var arguments = argv()
    if len(arguments) > 1 and arguments[1] == "sites":
        print_sites("fiber start+join, sequential", churn_program, 1_000)
        print_sites("callback completion", callback_program, 1_000)
        print_sites("root: Runtime.run(pure)", pure_program, 1, 1_000)
        return
    print("storage_cost: profile", IORuntimeConfig().profile)
    alloc_pair(1_000_000)
    roots("root: Runtime.run(pure)", 2_000)
    build_cost("flat_map chain", 0, 100_000)
    build_cost("map chain", 1, 100_000)
    build_cost("guarantee chain", 2, 100_000)
    build_cost("handle_error_with chain", 3, 100_000)
    run_cost("loop step through flat_map", loop_program, 100_000, 100_000)
    run_cost("nested defer level", deferred_program, 100_000, 100_000)
    run_cost("fiber start+join, sequential", churn_program, 10_000, 10_000)
    run_cost("fiber start+join, 1,000 live", many_program, 1_000, 1_000)
    run_cost("callback completion (IO.async_)", callback_program, 10_000, 10_000)
    run_cost("par_traverse element", par_program, 1_000, 1_000)
    run_cost("blocking call", blocking_program, 200, 200)
