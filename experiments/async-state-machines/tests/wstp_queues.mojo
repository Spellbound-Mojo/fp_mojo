"""Local rings and the external queue: exact single-thread contracts, then multi-thread stress.

Every element is a `Tracked` value; the ledger proves that each one is received
exactly once and destroyed exactly once, including elements left in destroyed
queues.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.os import getenv
from fp.effects._async.scheduling.external_queue import _ExternalQueue
from fp.effects._async.scheduling.local_queue import _LocalQueue
from fp.effects._async.scheduling.random import _Random
from wstp_support import check, Ledger, Tracked, WstpJob, wstp_start


def receive_all(ledger: Ledger, var item: Optional[Tracked]) -> Int:
    if item:
        var id = item.value().id
        ledger.receive(item.take())
        return id
    return -1


def single_thread_contracts():
    var ledger = Ledger(200)
    var random = _Random(1)
    var external = _ExternalQueue[Tracked](1)
    # FIFO order of the owner's own ring.
    var local = _LocalQueue[Tracked, 16, 4]()
    for i in range(10):
        local.enqueue(ledger.make(i), external, random)
    check(local.len() == 10, "ring length")
    for i in range(10):
        check(receive_all(ledger, local.dequeue()) == i, "ring FIFO order")
    check(not local.dequeue(), "empty ring")
    # Overflow: the 17th element spills the oldest half, 8 = 2 batches of 4.
    for i in range(10, 30):
        local.enqueue(ledger.make(i), external, random)
    check(external.approximate_len() == 8, "spilled half")
    check(local.len() == 12, "ring after spill")
    for i in range(10, 18):
        check(receive_all(ledger, external.pop(random)) == i, "external FIFO order")
    for i in range(18, 30):
        check(receive_all(ledger, local.dequeue()) == i, "ring order after spill")
    # Stealing half: 10 queued, the thief takes 5, returns the first, keeps 4.
    var thief = _LocalQueue[Tracked, 16, 4]()
    for i in range(30, 40):
        local.enqueue(ledger.make(i), external, random)
    check(receive_all(ledger, local.steal_into(thief)) == 30, "first stolen")
    check(thief.len() == 4 and local.len() == 5, "half stolen")
    for i in range(31, 35):
        check(receive_all(ledger, thief.dequeue()) == i, "stolen order")
    for i in range(35, 40):
        check(receive_all(ledger, local.dequeue()) == i, "victim keeps the rest")
    check(not local.steal_into(thief), "nothing to steal")
    # A refill takes one batch: the first is returned, the rest are queued.
    for i in range(40, 50):
        external.push(ledger.make(i), random)
    check(receive_all(ledger, local.enqueue_batch_from(external, random)) == 40, "batch head")
    check(local.len() == 3 and external.approximate_len() == 6, "batch size")
    for i in range(41, 44):
        check(receive_all(ledger, local.dequeue()) == i, "batch order")
    while receive_all(ledger, external.pop(random)) >= 0:
        pass
    # Leftovers in destroyed queues are destroyed exactly once.
    for i in range(50, 70):
        local.enqueue(ledger.make(i), external, random)
    for i in range(70, 80):
        external.push(ledger.make(i), random)
    _ = local^
    _ = thief^
    _ = external^
    ledger.verify("contracts", False, 80)
    for i in range(50):
        check(Int(ledger.state[].received.unsafe_offset(i)[].load()) == 1, "contracts received")


struct PoolState[capacity: Int, batch: Int](Movable):
    var locals: List[_LocalQueue[Tracked, Self.capacity, Self.batch]]
    var external: _ExternalQueue[Tracked]
    var steals: Atomic[Int]
    var external_takes: Atomic[Int]

    def __init__(out self, workers: Int):
        self.locals = List[_LocalQueue[Tracked, Self.capacity, Self.batch]](capacity=workers)
        for _ in range(workers):
            self.locals.append(_LocalQueue[Tracked, Self.capacity, Self.batch]())
        self.external = _ExternalQueue[Tracked](workers)
        self.steals = Atomic(0)
        self.external_takes = Atomic(0)


@fieldwise_init
struct PoolWorker[capacity: Int, batch: Int](WstpJob):
    """Produces its own range and consumes from its ring, the external queue, and victims."""
    var pool: ArcPointer[PoolState[Self.capacity, Self.batch]]
    var ledger: Ledger
    var index: Int
    var workers: Int
    var quota: Int
    var stop_at: Int

    def work(deinit self):
        var random = _Random(UInt64(self.index + 17))
        var steals = 0
        var external_takes = 0
        var produced = 0
        var first = self.index * self.quota
        self.ledger.arrive_and_wait()
        while self.ledger.received() < self.stop_at:
            var choice = random.below(16)
            if produced < self.quota and choice < 9:
                self.pool[].locals[self.index].enqueue(self.ledger.make(first + produced), self.pool[].external, random)
                produced += 1
            elif choice < 13:
                _ = receive_all(self.ledger, self.pool[].locals[self.index].dequeue())
            elif choice == 13:
                if receive_all(self.ledger, self.pool[].external.pop(random)) >= 0:
                    external_takes += 1
            elif choice == 14:
                if receive_all(self.ledger, self.pool[].locals[self.index].enqueue_batch_from(self.pool[].external, random)) >= 0:
                    external_takes += 1
            else:
                var victim = random.below(self.workers)
                if victim != self.index:
                    if receive_all(self.ledger, self.pool[].locals[victim].steal_into(self.pool[].locals[self.index])) >= 0:
                        steals += 1
        _ = self.pool[].steals.fetch_add(steals)
        _ = self.pool[].external_takes.fetch_add(external_takes)
        # Finish producing so that every element exists, even when stopping early.
        while produced < self.quota:
            self.pool[].locals[self.index].enqueue(self.ledger.make(first + produced), self.pool[].external, random)
            produced += 1


def pool_mix[capacity: Int, batch: Int](label: String, workers: Int, quota: Int, early: Bool) raises:
    var total = workers * quota
    var ledger = Ledger(total)
    var pool = ArcPointer(PoolState[capacity, batch](workers))
    var stop_at = total // 2 if early else total
    var a = wstp_start(PoolWorker[capacity, batch](pool.copy(), ledger.copy(), 0, workers, quota, stop_at))
    var b = wstp_start(PoolWorker[capacity, batch](pool.copy(), ledger.copy(), 1, workers, quota, stop_at))
    var c = wstp_start(PoolWorker[capacity, batch](pool.copy(), ledger.copy(), 2, workers, quota, stop_at))
    ledger.open_when_ready(workers)
    _ = a^.join()
    _ = b^.join()
    _ = c^.join()
    check(ledger.received() >= stop_at, label + ": received total")
    # Only spills feed the external queue here, so takes from it prove spills happened.
    check(pool[].steals.load() > 0, label + ": no steal succeeded")
    check(pool[].external_takes.load() > 0, label + ": no spill reached the external queue")
    # Join synchronizes with every worker; destroying the pool destroys leftovers.
    _ = pool^
    ledger.verify(label, not early)


@fieldwise_init
struct ExternalProducer(WstpJob):
    var queue: ArcPointer[_ExternalQueue[Tracked]]
    var ledger: Ledger
    var first: Int
    var count: Int

    def work(deinit self):
        var random = _Random(UInt64(self.first + 3))
        # Half through single pushes, half through ring spills of 4-element batches.
        var ring = _LocalQueue[Tracked, 8, 4]()
        self.ledger.arrive_and_wait()
        for i in range(self.count):
            if i % 2 == 0:
                self.queue[].push(self.ledger.make(self.first + i), random)
            else:
                ring.enqueue(self.ledger.make(self.first + i), self.queue[], random)
        while True:
            var item = ring.dequeue()
            if not item:
                break
            self.queue[].push(item.take(), random)


@fieldwise_init
struct ExternalConsumer(WstpJob):
    var queue: ArcPointer[_ExternalQueue[Tracked]]
    var ledger: Ledger
    var seed: Int
    var total: Int

    def work(deinit self):
        var random = _Random(UInt64(self.seed))
        self.ledger.arrive_and_wait()
        while self.ledger.received() < self.total:
            _ = receive_all(self.ledger, self.queue[].pop(random))


def external_mpmc(count: Int) raises:
    var ledger = Ledger(2 * count)
    var queue = ArcPointer(_ExternalQueue[Tracked](4))
    var p1 = wstp_start(ExternalProducer(queue.copy(), ledger.copy(), 0, count))
    var p2 = wstp_start(ExternalProducer(queue.copy(), ledger.copy(), count, count))
    var c1 = wstp_start(ExternalConsumer(queue.copy(), ledger.copy(), 5, 2 * count))
    var c2 = wstp_start(ExternalConsumer(queue.copy(), ledger.copy(), 6, 2 * count))
    ledger.open_when_ready(4)
    _ = p1^.join()
    _ = p2^.join()
    _ = c1^.join()
    _ = c2^.join()
    check(queue[].is_empty(), "external drained")
    _ = queue^
    ledger.verify("external", True)


def main() raises:
    # WSTP_SCALE multiplies the workload for local soaks; qualification uses 1.
    var scale = max(1, atol(getenv("WSTP_SCALE", "1")))
    single_thread_contracts()
    pool_mix[16, 4]("small rings", 3, 300_000 * scale, False)
    pool_mix[256, 32]("default rings", 3, 400_000 * scale, False)
    pool_mix[16, 4]("early stop", 3, 100_000 * scale, True)
    external_mpmc(200_000 * scale)
    print("wstp_queues: ring order, spills, steals, batches, pool mixes and external MPMC, each element once")
