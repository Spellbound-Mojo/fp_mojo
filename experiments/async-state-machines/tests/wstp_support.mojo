"""Support for the work-stealing structure clients: OS threads, tracked elements, a ledger.

`Tracked` elements record their destruction in a `Ledger`; consumers record
each element they receive before destroying it. `Ledger.verify` then proves
that every element was received at most once (exactly once when required) and
destroyed exactly once, including elements left in a destroyed structure.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.time import sleep, monotonic
from fp.effects import unsafe_start, Fiber, IO, IOContext, Outcome, ReaderAction


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


trait WstpJob(Movable & Deinitable):
    def work(deinit self):
        ...


struct WstpThread[J: WstpJob](ReaderAction):
    """Runs one job on its own OS thread through `unsafe_start`."""
    var job: Self.J
    comptime Family = IO[Error]
    comptime Env = IOContext[Error]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Error]

    def __init__(out self, var job: Self.J):
        self.job = job^

    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        self.job^.work()
        return Outcome[NoneType, Error](None)


def wstp_start[J: WstpJob](var job: J) raises -> Fiber[WstpThread[J]]:
    return unsafe_start(WstpThread[J](job^))


struct LedgerState(Movable):
    var received: Pointer[Atomic[UInt8], MutUntrackedOrigin]
    var destroyed: Pointer[Atomic[UInt8], MutUntrackedOrigin]
    var count: Int
    var gate: Atomic[Int]
    var ready: Atomic[Int]
    var total_received: Atomic[Int]

    def __init__(out self, count: Int):
        self.count = count
        self.received = unsafe_alloc[Atomic[UInt8]](count)
        self.destroyed = unsafe_alloc[Atomic[UInt8]](count)
        for i in range(count):
            self.received.unsafe_offset(i).unsafe_write(Atomic(UInt8(0)))
            self.destroyed.unsafe_offset(i).unsafe_write(Atomic(UInt8(0)))
        self.gate = Atomic(0)
        self.ready = Atomic(0)
        self.total_received = Atomic(0)

    def __deinit__(deinit self):
        self.received.unsafe_free()
        self.destroyed.unsafe_free()


struct Tracked(Movable):
    """A move-only element that records its single destruction."""
    var id: Int
    var destroyed: Pointer[Atomic[UInt8], MutUntrackedOrigin]

    def __init__(out self, id: Int, ledger: Ledger):
        self.id = id
        self.destroyed = ledger.state[].destroyed.unsafe_offset(id)

    def __deinit__(deinit self):
        _ = self.destroyed[].fetch_add[ordering=Ordering.RELAXED](1)


struct Ledger(Copyable):
    """Shared exactly-once accounting; copies share one state."""
    var state: ArcPointer[LedgerState]

    def __init__(out self, count: Int):
        self.state = ArcPointer(LedgerState(count))

    def make(self, id: Int) -> Tracked:
        return Tracked(id, self)

    def receive(self, var item: Tracked):
        """Record that a consumer took `item`, then destroy it."""
        _ = self.state[].received.unsafe_offset(item.id)[].fetch_add[ordering=Ordering.RELAXED](1)
        _ = self.state[].total_received.fetch_add[ordering=Ordering.RELAXED](1)

    def received(self) -> Int:
        return self.state[].total_received.load[ordering=Ordering.ACQUIRE]()

    def arrive_and_wait(self):
        """Count this thread as ready and spin until the gate opens."""
        _ = self.state[].ready.fetch_add(1)
        while self.state[].gate.load[ordering=Ordering.ACQUIRE]() == 0:
            pass

    def open_when_ready(self, threads: Int):
        var deadline = monotonic() + 10_000_000_000
        while self.state[].ready.load() < threads:
            check(monotonic() < deadline, "workers did not start")
            sleep(0.0001)
        self.state[].gate.store[ordering=Ordering.RELEASE](1)

    def verify(self, label: String, all_received: Bool, upto: Int = -1):
        """Every element below `upto` destroyed once and received at most (or exactly) once."""
        var limit = self.state[].count if upto < 0 else upto
        for i in range(limit):
            self.verify_one(label, i, all_received)

    def verify_one(self, label: String, id: Int, must_receive: Bool):
        var received = Int(self.state[].received.unsafe_offset(id)[].load())
        var destroyed = Int(self.state[].destroyed.unsafe_offset(id)[].load())
        if destroyed != 1:
            abort(label + ": element " + String(id) + " destroyed " + String(destroyed) + " times")
        if received > 1 or (must_receive and received != 1):
            abort(label + ": element " + String(id) + " received " + String(received) + " times")


@fieldwise_init
struct SmokeJob(WstpJob):
    var ledger: Ledger
    var first: Int

    def work(deinit self):
        self.ledger.arrive_and_wait()
        for i in range(self.first, self.first + 100):
            self.ledger.receive(self.ledger.make(i))


def main() raises:
    var ledger = Ledger(200)
    var a = wstp_start(SmokeJob(ledger.copy(), 0))
    var b = wstp_start(SmokeJob(ledger.copy(), 100))
    ledger.open_when_ready(2)
    _ = a^.join()
    _ = b^.join()
    check(ledger.received() == 200, "smoke total")
    ledger.verify("smoke", True)
    print("wstp_support: threads, tracked elements and the exactly-once ledger")
