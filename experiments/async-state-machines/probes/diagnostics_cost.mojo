"""The cost of fiber diagnostics: slot publication, snapshots and the reader count.

Build at -O3; timings, not qualified. Every fiber start registers a slot in
its root's table (`fp._internal.fiber_slots`) and every finish releases it;
`Driver.fibers()` and `Runtime.fibers()` scan the table. The probe reports:

1. **Slots alone.** One `register` plus `release` on a private table:
   unshared (the current-thread `Driver` table), shared (every `Runtime`
   root's table, whose release takes the Dekker handshake), and shared while
   another thread snapshots it in a loop, where a release may wait for a
   snapshot in progress.
2. **Snapshots.** `_FiberSlots.snapshot()` per call and per registered slot,
   unshared and shared, and `Driver.fibers()` and `Runtime.fibers()` with
   `PARKED` fibers parked, which also build their `FiberInfo` lists.
3. **The start-heavy and fiber-pair paths.** Sequential start/join churn and
   a pair of fibers joined together, on the profile `IORuntimeConfig()`
   selects (`-D FP_ASYNC_PROFILE`), alone and while another thread calls
   `Runtime.fibers()` once per millisecond, and in a loop; the slot pair's
   share of a start/join is reported beside it.

Wall times on a shared host vary; compare only runs taken back to back.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.time import perf_counter_ns, sleep
from fp.callables import OnceUnary
from fp.effects import CancellationToken, IOContext, Outcome, ReaderAction, unsafe_start
from fp.effects import Fiber as Thread
from fp.effects import IO as ThreadIO
from fp.effects.async_runtime import IO, Clock, Deferred, Driver, Fiber, IORuntimeConfig, Runtime
from fp._internal.fiber_slots import _FiberSlots

comptime SAMPLES = 7
comptime PARKED = 1_000


def check(condition: Bool, message: String):
    if not condition:
        abort(String("diagnostics_cost: ", message))


def median(mut values: List[Int]) -> Int:
    sort(values)
    return values[len(values) // 2]


def per(nanoseconds: Int, count: Int) -> String:
    var tenths = (nanoseconds * 10) // count
    return String(tenths // 10) + "." + String(tenths % 10)


def report(label: String, nanoseconds: Int, count: Int):
    print(label, "|", per(nanoseconds, count), "ns")


struct Words(Movable):
    """Atomic words in their own allocation, used through immutable `self` from every thread."""
    var words: Pointer[Atomic[Int], MutUntrackedOrigin]

    def __init__(out self):
        self.words = unsafe_alloc[Atomic[Int]](4)
        for i in range(4):
            self.words.unsafe_offset(i).unsafe_write(Atomic(0))

    def __deinit__(deinit self):
        for i in range(4):
            self.words.unsafe_offset(i).unsafe_deinit_pointee()
        self.words.unsafe_free()

    def get(self, index: Int) -> Int:
        return self.words[unsafe_offset=index].load[ordering=Ordering.ACQUIRE]()

    def set(self, index: Int, value: Int):
        self.words[unsafe_offset=index].store[ordering=Ordering.RELEASE](value)

    def bump(self, index: Int):
        _ = self.words[unsafe_offset=index].fetch_add[ordering=Ordering.RELAXED](1)


comptime STOP = 0
comptime READY = 1
comptime DONE = 2


# ===--- 1 and 2: the slot table alone ---=== #


struct Table(Movable):
    """A slot table and a task state word its entries point at."""
    var slots: _FiberSlots
    var state: Pointer[Atomic[UInt8], MutUntrackedOrigin]

    def __init__(out self, shared: Bool):
        self.slots = _FiberSlots()
        if shared:
            self.slots.share_snapshots()
        self.state = unsafe_alloc[Atomic[UInt8]](1)
        self.state.unsafe_write(Atomic(UInt8(1)))

    def __deinit__(deinit self):
        self.state.unsafe_deinit_pointee()
        self.state.unsafe_free()

    def task(self) -> UInt64:
        return UInt64(Int(self.state))


@fieldwise_init
struct Snapshotter(ReaderAction):
    """Snapshots a shared table in a loop until stopped."""
    var table: ArcPointer[Table]
    var words: ArcPointer[Words]
    comptime Family = ThreadIO[Error]
    comptime Env = IOContext[Error]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Error]

    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        self.words[].set(READY, 1)
        while self.words[].get(STOP) == 0:
            var views = self.table[].slots.snapshot()
            if len(views) > 0:
                self.words[].bump(DONE)
        return Outcome[NoneType, Error](None)


def slot_pairs(label: String, shared: Bool, contended: Bool) raises:
    comptime n = 2_000_000
    var table = ArcPointer(Table(shared))
    var words = ArcPointer(Words())
    # A few long-lived entries, so a snapshot always has something to read.
    for _ in range(16):
        _ = table[].slots.register(0, table[].task())
    var helpers = List[Thread[Snapshotter]]()
    if contended:
        helpers.append(unsafe_start(Snapshotter(table.copy(), words.copy())))
        while words[].get(READY) == 0:
            sleep(0.0001)
    var times = List[Int]()
    var task = table[].task()
    for _ in range(SAMPLES):
        var started = perf_counter_ns()
        for _ in range(n):
            var slot = table[].slots.register(0, task)
            table[].slots.release(slot)
        times.append(Int(perf_counter_ns() - started))
    words[].set(STOP, 1)
    while helpers:
        _ = helpers.pop().join()
    var suffix = String("")
    if contended:
        suffix = String(" (", words[].get(DONE), " snapshots meanwhile)")
    report("slot register+release, " + label + suffix, median(times), n)


def snapshots(label: String, shared: Bool, registered: Int):
    var table = Table(shared)
    for _ in range(registered):
        _ = table.slots.register(0, table.task())
    var calls = max(100, 200_000 // max(1, registered))
    var times = List[Int]()
    var total = 0
    for _ in range(SAMPLES):
        var started = perf_counter_ns()
        for _ in range(calls):
            total += len(table.slots.snapshot())
        times.append(Int(perf_counter_ns() - started))
    check(total == SAMPLES * calls * registered, "every registered slot listed")
    var each = median(times) // calls
    print("snapshot, " + label + ",", registered, "slots |", each, "ns per call |", per(each, max(1, registered)), "ns per slot")


# ===--- Programs with parked fibers ---=== #


@fieldwise_init
struct StartParked(OnceUnary):
    """Start `remaining` fibers that wait on `gate`, then wait on it too and join them."""
    var gate: Deferred[Int]
    var fibers: List[Fiber[Int, Int]]
    var remaining: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var ignored: Int) -> IO[Int, Int]:
        if self.remaining == 0:
            return self.gate.get[Int]().flat_map(JoinAll(self.fibers^))
        return self.gate.get[Int]().start().flat_map(KeepParked(self.gate^, self.fibers^, self.remaining))


@fieldwise_init
struct KeepParked(OnceUnary):
    var gate: Deferred[Int]
    var fibers: List[Fiber[Int, Int]]
    var remaining: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        self.fibers.append(fiber^)
        return IO[Int, Int].pure(0).flat_map(StartParked(self.gate^, self.fibers^, self.remaining - 1))


@fieldwise_init
struct JoinAll(OnceUnary):
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
        return IO[Int, Int].pure(self.total + outcome.take()._take_ok()).flat_map(JoinAll(self.fibers^))


def parked(gate: Deferred[Int], count: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(0).flat_map(StartParked(gate.copy(), List[Fiber[Int, Int]](), count))


def driver_snapshots() raises:
    var gate = Deferred[Int]()
    var config = IORuntimeConfig()
    var driver = Driver(parked(gate, PARKED), CancellationToken(), Clock(), config)
    while True:
        var progress = driver.poll()
        if progress.completed or not progress.runnable:
            break
    check(len(driver.fibers()) == PARKED, "every parked fiber listed")
    var calls = 200
    var times = List[Int]()
    for _ in range(SAMPLES):
        var started = perf_counter_ns()
        for _ in range(calls):
            _ = len(driver.fibers())
        times.append(Int(perf_counter_ns() - started))
    var each = median(times) // calls
    print("Driver.fibers(),", PARKED, "parked |", each, "ns per call |", per(each, PARKED), "ns per fiber")
    var opener = Driver(gate.complete[Int](1))
    while not opener.poll().completed:
        pass
    _ = opener^.finish()
    while not driver.poll().completed:
        pass
    var outcome = driver^.finish()
    check(Bool(outcome) and outcome.value().is_ok(), "the parked program finished")


@fieldwise_init
struct RunParked(ReaderAction):
    """Run the parked program on the runtime from another thread."""
    var runtime: Runtime
    var gate: Deferred[Int]
    var words: ArcPointer[Words]
    comptime Family = ThreadIO[Error]
    comptime Env = IOContext[Error]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Error]

    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        var outcome = self.runtime.run(parked(self.gate, PARKED))
        if not outcome or not outcome.value().is_ok():
            abort("diagnostics_cost: the parked program failed")
        self.words[].set(DONE, 1)
        return Outcome[NoneType, Error](None)


def runtime_snapshots(runtime: Runtime) raises:
    var gate = Deferred[Int]()
    var words = ArcPointer(Words())
    var runner = unsafe_start(RunParked(runtime.copy(), gate.copy(), words.copy()))
    while len(runtime.fibers()) != PARKED:
        sleep(0.0001)
    var calls = 200
    var times = List[Int]()
    for _ in range(SAMPLES):
        var started = perf_counter_ns()
        for _ in range(calls):
            _ = len(runtime.fibers())
        times.append(Int(perf_counter_ns() - started))
    var each = median(times) // calls
    print("Runtime.fibers(),", PARKED, "parked |", each, "ns per call |", per(each, PARKED), "ns per fiber")
    _ = runtime.run(gate.complete[Int](1))
    _ = runner^.join()
    check(words[].get(DONE) == 1, "the parked program finished")


# ===--- 3: start-heavy and fiber-pair paths ---=== #


@fieldwise_init
struct Churn(OnceUnary):
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
        return IO[Int, Int].pure(outcome.take()._take_ok() + 1).flat_map(Churn(self.limit))


@fieldwise_init
struct Pair(OnceUnary):
    """Start two fibers, join both, and repeat `limit` times."""
    var limit: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var count: Int) -> IO[Int, Int]:
        if count == self.limit:
            return IO[Int, Int].pure(count)
        return IO[Int, Int].pure(1).start().flat_map(StartSecond(self.limit, count))


@fieldwise_init
struct StartSecond(OnceUnary):
    var limit: Int
    var count: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var first: Fiber[Int, Int]) -> IO[Int, Int]:
        return IO[Int, Int].pure(2).start().flat_map(JoinBoth(first^, self.limit, self.count))


@fieldwise_init
struct JoinBoth(OnceUnary):
    var first: Fiber[Int, Int]
    var limit: Int
    var count: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var second: Fiber[Int, Int]) -> IO[Int, Int]:
        return self.first^.join().flat_map(JoinOther(second^, self.limit, self.count))


@fieldwise_init
struct JoinOther(OnceUnary):
    var second: Fiber[Int, Int]
    var limit: Int
    var count: Int
    comptime Arg = Outcome[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> IO[Int, Int]:
        return self.second^.join().flat_map(NextPair(self.limit, self.count))


@fieldwise_init
struct NextPair(OnceUnary):
    var limit: Int
    var count: Int
    comptime Arg = Outcome[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> IO[Int, Int]:
        return IO[Int, Int].pure(self.count + 1).flat_map(Pair(self.limit))


@fieldwise_init
struct Watcher(ReaderAction):
    """Calls `Runtime.fibers()` in a loop, or once per millisecond, until stopped."""
    var runtime: Runtime
    var words: ArcPointer[Words]
    var paced: Bool
    comptime Family = ThreadIO[Error]
    comptime Env = IOContext[Error]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Error]

    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        self.words[].set(READY, 1)
        while self.words[].get(STOP) == 0:
            _ = len(self.runtime.fibers())
            self.words[].bump(DONE)
            if self.paced:
                sleep(0.001)
        return Outcome[NoneType, Error](None)


def paths(runtime: Runtime, watched: Bool, paced: Bool = False) raises -> Int:
    """Time churn and pairs; returns the churn's median per cycle."""
    comptime cycles = 20_000
    var words = ArcPointer(Words())
    var helpers = List[Thread[Watcher]]()
    if watched:
        helpers.append(unsafe_start(Watcher(runtime.copy(), words.copy(), paced)))
        while words[].get(READY) == 0:
            sleep(0.0001)
    var churn = List[Int]()
    var pairs = List[Int]()
    for _ in range(SAMPLES):
        var started = perf_counter_ns()
        _ = runtime.run(IO[Int, Int].pure(0).flat_map(Churn(cycles)))
        churn.append(Int(perf_counter_ns() - started))
        started = perf_counter_ns()
        _ = runtime.run(IO[Int, Int].pure(0).flat_map(Pair(cycles // 2)))
        pairs.append(Int(perf_counter_ns() - started))
    words[].set(STOP, 1)
    while helpers:
        _ = helpers.pop().join()
    var label = String(", unwatched")
    if watched:
        label = String(", watched (", words[].get(DONE), " Runtime.fibers() calls", ", one per ms)" if paced else ", in a loop)")
    var each = median(churn)
    report("start+join, sequential" + label, each, cycles)
    report("fiber pair (start two, join two)" + label, median(pairs), cycles // 2)
    return each // cycles


def main() raises:
    var config = IORuntimeConfig()
    print("diagnostics_cost: profile", config.profile)
    slot_pairs("unshared", False, False)
    slot_pairs("shared", True, False)
    slot_pairs("shared, one thread snapshotting", True, True)
    for registered in [0, 16, 1024]:
        snapshots("unshared", False, registered)
        snapshots("shared", True, registered)
    driver_snapshots()
    var runtime = Runtime(config)
    runtime_snapshots(runtime)
    var unwatched = paths(runtime, False)
    _ = paths(runtime, True, True)
    _ = paths(runtime, True)
    print("start+join per cycle", unwatched, "ns; compare the slot pair above")
