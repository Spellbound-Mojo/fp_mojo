"""Diagnostic timings for the work-stealing structures (build at -O3; not qualified).

Reports nanoseconds per operation for atomic operations against plain ones, the
local ring, the external queue, and the timer heap, uncontended and contended,
for comparison with the run loop's 50-60 ns step. Elements are `Int`, the size
of a task handle. Compilation is not timed. Wall times on a shared host vary;
compare only runs taken back to back.
"""
from std.atomic import Atomic, Ordering, fence
from std.collections import BinaryHeap, Deque
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.time import perf_counter_ns, sleep
from fp._internal.cells import _Cell, _lock_metadata
from fp.effects import unsafe_start, Fiber, IO, IOContext, Outcome, ReaderAction
from fp.effects._async.scheduling.external_queue import _ExternalQueue
from fp.effects._async.scheduling.local_queue import _LocalQueue
from fp.effects._async.scheduling.random import _Random
from fp.effects._async.scheduling.timer_heap import _TimerHeap


def report(label: String, nanoseconds: Int, operations: Int):
    var per = Float64(nanoseconds) / Float64(operations)
    print(label, ":", per, "ns/op")


@no_inline
def sink(value: UInt64):
    if value == 0xDEADBEEF12345:
        print("unlikely", value)


def atomic_costs():
    """Loads and stores walk a 4 KiB array so that the compiler cannot hoist or merge them."""
    comptime n = 50_000_000
    comptime mask = 511
    var cells = unsafe_alloc[Atomic[UInt64]](mask + 1)
    var plain = unsafe_alloc[UInt64](mask + 1)
    for i in range(mask + 1):
        cells.unsafe_offset(i).unsafe_write(Atomic(UInt64(i)))
        plain.unsafe_offset(i).unsafe_write(UInt64(i))
    var total = UInt64(0)
    var t = perf_counter_ns()
    for i in range(n):
        total += plain[unsafe_offset=(i * 7) & mask]
    report("plain load", perf_counter_ns() - t, n)
    t = perf_counter_ns()
    for i in range(n):
        total += cells[unsafe_offset=(i * 7) & mask].load[ordering=Ordering.RELAXED]()
    report("relaxed load", perf_counter_ns() - t, n)
    t = perf_counter_ns()
    for i in range(n):
        total += cells[unsafe_offset=(i * 7) & mask].load[ordering=Ordering.ACQUIRE]()
    report("acquire load", perf_counter_ns() - t, n)
    t = perf_counter_ns()
    for i in range(n):
        total += cells[unsafe_offset=(i * 7) & mask].load[ordering=Ordering.SEQUENTIAL]()
    report("sequential load", perf_counter_ns() - t, n)
    t = perf_counter_ns()
    for i in range(n):
        plain[unsafe_offset=(i * 7) & mask] = UInt64(i)
    report("plain store", perf_counter_ns() - t, n)
    t = perf_counter_ns()
    for i in range(n):
        cells[unsafe_offset=(i * 7) & mask].store[ordering=Ordering.RELEASE](UInt64(i))
    report("release store", perf_counter_ns() - t, n)
    t = perf_counter_ns()
    for i in range(n // 10):
        cells[unsafe_offset=(i * 7) & mask].store[ordering=Ordering.SEQUENTIAL](UInt64(i))
    report("sequential store", perf_counter_ns() - t, n // 10)
    t = perf_counter_ns()
    for i in range(n // 10):
        plain[unsafe_offset=(i * 7) & mask] += 1
    report("plain increment", perf_counter_ns() - t, n // 10)
    t = perf_counter_ns()
    for i in range(n // 10):
        total += cells[unsafe_offset=(i * 7) & mask].fetch_add[ordering=Ordering.RELAXED](1)
    report("relaxed fetch_add", perf_counter_ns() - t, n // 10)
    t = perf_counter_ns()
    for i in range(n // 10):
        total += cells[unsafe_offset=(i * 7) & mask].fetch_add[ordering=Ordering.SEQUENTIAL](1)
    report("sequential fetch_add", perf_counter_ns() - t, n // 10)
    t = perf_counter_ns()
    for i in range(n // 10):
        ref cell = cells[unsafe_offset=(i * 7) & mask]
        var expected = cell.load[ordering=Ordering.RELAXED]()
        _ = cell.compare_exchange[success_ordering=Ordering.RELAXED, failure_ordering=Ordering.RELAXED](expected, expected + 1)
    report("load + successful relaxed compare_exchange", perf_counter_ns() - t, n // 10)
    t = perf_counter_ns()
    for i in range(n // 10):
        ref cell = cells[unsafe_offset=(i * 7) & mask]
        var expected = cell.load[ordering=Ordering.RELAXED]()
        _ = cell.compare_exchange[success_ordering=Ordering.ACQUIRE_RELEASE, failure_ordering=Ordering.ACQUIRE](expected, expected + 1)
    report("load + successful acquire-release compare_exchange", perf_counter_ns() - t, n // 10)
    t = perf_counter_ns()
    for i in range(n // 10):
        plain[unsafe_offset=(i * 7) & mask] = UInt64(i)
        fence[Ordering.SEQUENTIAL]()
    report("plain store + sequential fence", perf_counter_ns() - t, n // 10)
    for i in range(mask + 1):
        total += plain[unsafe_offset=i] + cells[unsafe_offset=i].load()
    sink(total)
    cells.unsafe_free()
    plain.unsafe_free()


def ring_uncontended():
    comptime n = 20_000_000
    var random = _Random(1)
    var external = _ExternalQueue[Int](4)
    var ring = _LocalQueue[Int]()
    var total = 0
    var t = perf_counter_ns()
    for i in range(n):
        ring.enqueue(i, external, random)
        total += ring.dequeue().value()
    report("ring enqueue+dequeue pair", perf_counter_ns() - t, n)
    t = perf_counter_ns()
    for _ in range(n // 128):
        for i in range(128):
            ring.enqueue(i, external, random)
        for _ in range(128):
            total += ring.dequeue().value()
    report("ring enqueue then dequeue, per element (128 deep)", perf_counter_ns() - t, n)
    var thief = _LocalQueue[Int]()
    var stolen = 0
    t = perf_counter_ns()
    for _ in range(n // 256):
        for i in range(256):
            ring.enqueue(i, external, random)
        while True:
            var first = ring.steal_into(thief)
            if not first:
                break
            stolen += 1
            while thief.dequeue():
                stolen += 1
        while ring.dequeue():
            stolen += 1
    report("fill 256, steal halves until empty, per element", perf_counter_ns() - t, (n // 256) * 256)
    t = perf_counter_ns()
    for i in range(n // 4):
        ring.enqueue(i, external, random)
    report("enqueue with spills to the external queue, per element", perf_counter_ns() - t, n // 4)
    sink(UInt64(total + stolen + external.approximate_len()))


def external_uncontended():
    comptime n = 5_000_000
    var random = _Random(2)
    var external = _ExternalQueue[Int](4)
    var total = 0
    var t = perf_counter_ns()
    for i in range(n):
        external.push(i, random)
        total += external.pop(random).value()
    report("external push+pop pair (_lock_metadata stripes)", perf_counter_ns() - t, n)
    # The same work under a hand-written lock that borrows the cell instead of
    # copying its ArcPointer, to price the shared guard's reference counting.
    var cell = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(Deque[Int]())))
    t = perf_counter_ns()
    for i in range(n):
        while True:
            var expected = UInt8(0)
            if cell[].lock.compare_exchange[success_ordering=Ordering.ACQUIRE, failure_ordering=Ordering.RELAXED](expected, 1):
                break
        cell[].slot.value().append(i)
        cell[].lock.store[ordering=Ordering.RELEASE](0)
        while True:
            var expected = UInt8(0)
            if cell[].lock.compare_exchange[success_ordering=Ordering.ACQUIRE, failure_ordering=Ordering.RELAXED](expected, 1):
                break
        try:
            total += cell[].slot.value().popleft()
        except:
            abort("empty")
        cell[].lock.store[ordering=Ordering.RELEASE](0)
    report("hand-written borrowed spin lock push+pop pair", perf_counter_ns() - t, n)
    sink(UInt64(total))


@fieldwise_init
struct Due(Copyable, Comparable):
    """A min-heap key for the standard library's max-heap."""
    var deadline: UInt64
    var id: Int

    def __lt__(self, other: Self) -> Bool:
        return self.deadline > other.deadline
    def __eq__(self, other: Self) -> Bool:
        return self.deadline == other.deadline
    def __ne__(self, other: Self) -> Bool:
        return not self == other
    def __le__(self, other: Self) -> Bool:
        return self < other or self == other
    def __gt__(self, other: Self) -> Bool:
        return other < self
    def __ge__(self, other: Self) -> Bool:
        return other <= self


def timers_uncontended():
    comptime n = 2_000_000
    var heap = _TimerHeap[Int]()
    var random = _Random(3)
    for i in range(1000):
        _ = heap.insert(UInt64(1_000_000_000 + i), i)
    var total = 0
    var t = perf_counter_ns()
    for i in range(n):
        _ = heap.insert(UInt64(i + random.below(1000)), i)
        var item = heap.poll_expired(UInt64(i))
        if item:
            total += item.value()
    report("timer insert + poll (1000 far timers queued)", perf_counter_ns() - t, n)
    var baseline = BinaryHeap[Due]()
    for i in range(1000):
        baseline.push(Due(UInt64(1_000_000_000 + i), i))
    t = perf_counter_ns()
    for i in range(n):
        baseline.push(Due(UInt64(i + random.below(1000)), i))
        if baseline.peek().deadline <= UInt64(i):
            total += baseline.pop().id
    report("  baseline: std BinaryHeap push + pop, same workload", perf_counter_ns() - t, n)
    t = perf_counter_ns()
    for i in range(n):
        var ticket = heap.insert(UInt64(2_000_000_000 + i), i)
        total += heap.cancel_owned(ticket).value()
    report("timer insert + owner cancel", perf_counter_ns() - t, n)
    t = perf_counter_ns()
    for i in range(n):
        var ticket = heap.insert(UInt64(2_000_000_000 + i), i)
        total += heap.cancel(ticket).value()
    report("timer insert + marked cancel (packs amortized)", perf_counter_ns() - t, n)
    var out = List[Int]()
    t = perf_counter_ns()
    var stolen = 0
    for round in range(n // 100):
        for i in range(100):
            _ = heap.insert(UInt64(round), i)
        stolen += heap.steal_into(UInt64(round), out, 100)
        while out:
            total += out.pop()
        while heap.poll_expired(UInt64(round)):
            pass
    report("timer insert + steal (100 due), per timer", perf_counter_ns() - t, (n // 100) * 100)
    sink(UInt64(total + stolen))


struct Shared(Movable):
    var ring: _LocalQueue[Int]
    var thieves: List[_LocalQueue[Int]]
    var external: _ExternalQueue[Int]
    var heap: _TimerHeap[Int]
    var stop: Atomic[Int]
    var ready: Atomic[Int]
    var work: Atomic[Int]
    var clock: Atomic[UInt64]

    def __init__(out self):
        self.ring = _LocalQueue[Int]()
        self.thieves = List[_LocalQueue[Int]]()
        for _ in range(3):
            self.thieves.append(_LocalQueue[Int]())
        self.external = _ExternalQueue[Int](4)
        self.heap = _TimerHeap[Int]()
        self.stop = Atomic(0)
        self.ready = Atomic(0)
        self.work = Atomic(0)
        self.clock = Atomic(UInt64(0))


@fieldwise_init
struct Thief(ReaderAction):
    """Steals from the shared ring (mode 0), pushes and pops externally (1), or steals due timers (2)."""
    var shared: ArcPointer[Shared]
    var index: Int
    var mode: Int
    comptime Family = IO[Error]
    comptime Env = IOContext[Error]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Error]

    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        var random = _Random(UInt64(self.index + 40))
        var out = List[Int]()
        var done = 0
        _ = self.shared[].ready.fetch_add(1)
        while self.shared[].stop.load[ordering=Ordering.RELAXED]() == 0:
            if self.mode == 0:
                if self.shared[].ring.steal_into(self.shared[].thieves[self.index]):
                    done += 1
                    while self.shared[].thieves[self.index].dequeue():
                        done += 1
            elif self.mode == 1:
                self.shared[].external.push(done, random)
                if self.shared[].external.pop(random):
                    done += 1
            else:
                done += self.shared[].heap.steal_into(self.shared[].clock.load[ordering=Ordering.RELAXED](), out, 8)
                out.clear()
        _ = self.shared[].work.fetch_add(done)
        return Outcome[NoneType, Error](None)


def start_helpers(shared: ArcPointer[Shared], mode: Int, count: Int) raises -> List[Fiber[Thief]]:
    var helpers = List[Fiber[Thief]]()
    for i in range(count):
        helpers.append(unsafe_start(Thief(shared.copy(), i, mode)))
    while shared[].ready.load() < count:
        sleep(0.0001)
    return helpers^


def stop_helpers(shared: ArcPointer[Shared], var helpers: List[Fiber[Thief]]) -> Int:
    shared[].stop.store(1)
    while helpers:
        _ = helpers.pop().join()
    var done = shared[].work.load()
    shared[].stop.store(0)
    shared[].ready.store(0)
    shared[].work.store(0)
    return done


def contended() raises:
    comptime n = 5_000_000
    var shared = ArcPointer(Shared())
    var random = _Random(5)
    var total = 0
    # The owner keeps 64 elements queued so that thieves find work.
    for i in range(64):
        shared[].ring.enqueue(i, shared[].external, random)
    var helpers = start_helpers(shared, 0, 2)
    var t = perf_counter_ns()
    for i in range(n):
        shared[].ring.enqueue(i, shared[].external, random)
        var item = shared[].ring.dequeue()
        if item:
            total += item.value()
    var elapsed = perf_counter_ns() - t
    var stolen = stop_helpers(shared, helpers^)
    report("ring enqueue+dequeue pair, 2 thieves stealing", elapsed, n)
    print("  elements stolen meanwhile:", stolen)
    helpers = start_helpers(shared, 1, 3)
    t = perf_counter_ns()
    for i in range(n // 5):
        shared[].external.push(i, random)
        var item = shared[].external.pop(random)
        if item:
            total += item.value()
    elapsed = perf_counter_ns() - t
    var others = stop_helpers(shared, helpers^)
    report("external push+pop pair, 3 other threads doing the same", elapsed, n // 5)
    print("  pairs by the other threads meanwhile:", others)
    for i in range(1000):
        _ = shared[].heap.insert(UInt64(1_000_000_000 + i), i)
    helpers = start_helpers(shared, 2, 2)
    t = perf_counter_ns()
    for i in range(n // 5):
        if i % 64 == 0:
            shared[].clock.store[ordering=Ordering.RELAXED](UInt64(i))
        _ = shared[].heap.insert(UInt64(i + 1000), i)
        var item = shared[].heap.poll_expired(UInt64(i))
        if item:
            total += item.value()
    elapsed = perf_counter_ns() - t
    var walks = stop_helpers(shared, helpers^)
    report("timer insert + poll, 2 threads stealing due timers", elapsed, n // 5)
    print("  timers stolen meanwhile:", walks)
    sink(UInt64(total))


def main() raises:
    atomic_costs()
    ring_uncontended()
    external_uncontended()
    timers_uncontended()
    contended()
