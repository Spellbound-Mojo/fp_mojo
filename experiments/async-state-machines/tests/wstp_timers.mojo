"""Per-worker timer heap: exact owner contracts, then cross-thread cancellation and stealing.

One owner thread inserts and fires timers on a virtual clock and publishes
tickets through a mailbox; other threads cancel published tickets and steal
expired timers. The ledger proves that every payload leaves the heap exactly
once and is destroyed exactly once, including payloads left in a destroyed heap.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import getenv
from fp._internal.waking import _Ticket
from fp.effects._async.scheduling.random import _Random
from fp.effects._async.scheduling.timer_heap import _TimerHeap
from wstp_support import check, Ledger, Tracked, WstpJob, wstp_start


def id_of(ledger: Ledger, var item: Optional[Tracked]) -> Int:
    if item:
        var id = item.value().id
        ledger.receive(item.take())
        return id
    return -1


def owner_contracts():
    var ledger = Ledger(400)
    var heap = _TimerHeap[Tracked]()
    # Deadline order.
    var deadlines = [50, 10, 40, 20, 30]
    for i in range(5):
        _ = heap.insert(UInt64(deadlines[i]), ledger.make(deadlines[i]))
    check(id_of(ledger, heap.poll_expired(25)) == 10, "earliest first")
    check(id_of(ledger, heap.poll_expired(25)) == 20, "second earliest")
    check(not heap.poll_expired(25), "nothing else due")
    check(heap.next_deadline().value() == 30, "next deadline")
    for expected in [30, 40, 50]:
        check(id_of(ledger, heap.poll_expired(100)) == expected, "remaining order")
    check(not heap.next_deadline(), "empty heap")
    # Owner cancellation removes at once; a repeated cancellation finds nothing.
    var a = heap.insert(5, ledger.make(100))
    var b = heap.insert(6, ledger.make(101))
    var c = heap.insert(7, ledger.make(102))
    check(id_of(ledger, heap.cancel_owned(b)) == 101, "owner cancel")
    check(heap.len() == 2, "owner cancel removes the entry")
    check(not heap.cancel_owned(b) and not heap.cancel(b), "repeated cancel")
    check(id_of(ledger, heap.poll_expired(10)) == 100 and id_of(ledger, heap.poll_expired(10)) == 102, "rest fire")
    check(not heap.cancel(a) and not heap.cancel(c), "cancel after firing")
    # A stale ticket never cancels the slot's next timer.
    var reused = heap.insert(8, ledger.make(103))
    check(reused.index == a.index or reused.index == b.index or reused.index == c.index, "slot reused")
    check(not heap.cancel(a) and not heap.cancel(b) and not heap.cancel(c), "stale tickets")
    check(id_of(ledger, heap.cancel(reused)) == 103, "live ticket")
    # Marked cancellations stay until they reach half the heap, then one pack removes them.
    var tickets = List[_Ticket]()
    for i in range(100):
        tickets.append(heap.insert(UInt64(1000 + i), ledger.make(200 + i)))
    for i in range(60):
        check(id_of(ledger, heap.cancel(tickets[i])) == 200 + i, "marked cancel")
    # The earlier marked cancellation was packed away by the first of these inserts.
    check(heap.len() == 100, "marks are lazy")
    _ = heap.insert(5000, ledger.make(300))
    check(heap.len() == 41, "pack removed the marked entries")
    for i in range(60, 100):
        check(id_of(ledger, heap.poll_expired(UInt64.MAX)) == 200 + i, "order after pack")
    check(id_of(ledger, heap.poll_expired(UInt64.MAX)) == 300, "last after pack")
    # Stealing takes due timers only and leaves the entries for the owner to retire.
    for i in range(10):
        _ = heap.insert(UInt64(i), ledger.make(310 + i))
        _ = heap.insert(UInt64(100 + i), ledger.make(320 + i))
    var stolen = List[Tracked]()
    check(heap.steal_into(9, stolen, 100) == 10, "steal due timers")
    var seen = 0
    while stolen:
        var item = stolen.pop()
        check(item.id >= 310 and item.id < 320, "only due timers stolen")
        seen += 1
        ledger.receive(item^)
    check(seen == 10, "stolen count")
    check(not heap.poll_expired(9), "stolen timers do not fire again")
    check(heap.len() == 10, "stolen entries retired")
    check(heap.steal_into(9, stolen, 100) == 0, "nothing more to steal")
    # Payloads left in a destroyed heap are destroyed exactly once.
    _ = heap^
    # Ids 10..50 by tens, 100..103, 200..300 and 310..329 were created; all but
    # the 10 far timers (320..329) left the heap before it was destroyed.
    for id in range(330):
        var created = (id >= 10 and id <= 50 and id % 10 == 0) or (id >= 100 and id <= 103) or (id >= 200 and id <= 300) or id >= 310
        if created:
            ledger.verify_one("owner contracts", id, id < 320)


struct TimerRig(Movable):
    var heap: _TimerHeap[Tracked]
    var mailbox: Pointer[Atomic[UInt64], MutUntrackedOrigin]
    var clock: Atomic[UInt64]
    var done: Atomic[Int]
    var canceled: Atomic[Int]
    var stolen: Atomic[Int]
    comptime slots = 1024

    def __init__(out self):
        self.heap = _TimerHeap[Tracked]()
        self.mailbox = unsafe_alloc[Atomic[UInt64]](Self.slots)
        for i in range(Self.slots):
            self.mailbox.unsafe_offset(i).unsafe_write(Atomic(UInt64(0)))
        self.clock = Atomic(UInt64(0))
        self.done = Atomic(0)
        self.canceled = Atomic(0)
        self.stolen = Atomic(0)

    def __deinit__(deinit self):
        self.mailbox.unsafe_free()


def pack_ticket(ticket: _Ticket) -> UInt64:
    return (ticket.generation << 24) | UInt64(ticket.index)


def unpack_ticket(word: UInt64) -> _Ticket:
    return _Ticket(Int(word & 0xFFFFFF), word >> 24)


@fieldwise_init
struct TimerOwner(WstpJob):
    var rig: ArcPointer[TimerRig]
    var ledger: Ledger
    var rounds: Int
    var per_round: Int
    var drain: Bool

    def work(deinit self):
        var random = _Random(99)
        var next_id = 0
        var recent = List[_Ticket]()
        self.ledger.arrive_and_wait()
        for round in range(self.rounds):
            var now = UInt64(round)
            self.rig[].clock.store[ordering=Ordering.RELEASE](now)
            for _ in range(self.per_round):
                var ticket = self.rig[].heap.insert(now + UInt64(random.below(64)), self.ledger.make(next_id))
                next_id += 1
                # RELEASE publishes the ticket and the slot chunk it names to cancelers.
                self.rig[].mailbox[unsafe_offset=random.below(TimerRig.slots)].store[ordering=Ordering.RELEASE](pack_ticket(ticket))
                if random.below(8) == 0:
                    recent.append(ticket.copy())
            while id_of(self.ledger, self.rig[].heap.poll_expired(now)) >= 0:
                pass
            if recent and random.below(4) == 0:
                _ = id_of(self.ledger, self.rig[].heap.cancel_owned(recent.pop()))
        if self.drain:
            while self.rig[].heap.len() > 0:
                _ = id_of(self.ledger, self.rig[].heap.poll_expired(UInt64.MAX))
        self.rig[].done.store[ordering=Ordering.RELEASE](1)


@fieldwise_init
struct TimerHelper(WstpJob):
    """Cancels published tickets and steals due timers until the owner finishes."""
    var rig: ArcPointer[TimerRig]
    var ledger: Ledger
    var seed: Int
    var cancels: Bool
    var steals: Bool

    def work(deinit self):
        var random = _Random(UInt64(self.seed))
        var out = List[Tracked]()
        var canceled = 0
        var stolen = 0
        self.ledger.arrive_and_wait()
        while self.rig[].done.load[ordering=Ordering.ACQUIRE]() == 0:
            if self.cancels:
                var index = random.below(TimerRig.slots)
                var word = self.rig[].mailbox[unsafe_offset=index].load[ordering=Ordering.ACQUIRE]()
                if word != 0 and self.rig[].mailbox[unsafe_offset=index].compare_exchange[success_ordering=Ordering.ACQUIRE, failure_ordering=Ordering.RELAXED](word, 0):
                    if id_of(self.ledger, self.rig[].heap.cancel(unpack_ticket(word))) >= 0:
                        canceled += 1
            if self.steals:
                var now = self.rig[].clock.load[ordering=Ordering.ACQUIRE]()
                stolen += self.rig[].heap.steal_into(now, out, 8)
                while out:
                    self.ledger.receive(out.pop())
        _ = self.rig[].canceled.fetch_add(canceled)
        _ = self.rig[].stolen.fetch_add(stolen)


def timer_storm(label: String, rounds: Int, per_round: Int, drain: Bool) raises:
    var total = rounds * per_round
    var ledger = Ledger(total)
    var rig = ArcPointer(TimerRig())
    var owner = wstp_start(TimerOwner(rig.copy(), ledger.copy(), rounds, per_round, drain))
    var canceler = wstp_start(TimerHelper(rig.copy(), ledger.copy(), 7, True, False))
    var thief = wstp_start(TimerHelper(rig.copy(), ledger.copy(), 8, False, True))
    var both = wstp_start(TimerHelper(rig.copy(), ledger.copy(), 9, True, True))
    ledger.open_when_ready(4)
    _ = owner^.join()
    _ = canceler^.join()
    _ = thief^.join()
    _ = both^.join()
    check(rig[].canceled.load() > 0, label + ": no cross-thread cancellation succeeded")
    check(rig[].stolen.load() > 0, label + ": no timer was stolen")
    if drain:
        check(ledger.received() == total, label + ": every timer left the heap")
    _ = rig^
    ledger.verify(label, drain)


def main() raises:
    # WSTP_SCALE multiplies the workload for local soaks; qualification uses 1.
    var scale = max(1, atol(getenv("WSTP_SCALE", "1")))
    owner_contracts()
    timer_storm("timer storm", 40_000 * scale, 16, True)
    timer_storm("timer leftovers", 10_000 * scale, 16, False)
    print("wstp_timers: deadline order, owner and cross-thread cancellation, packing, stealing, each payload once")
