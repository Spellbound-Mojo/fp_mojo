"""The one-shot slot on four OS threads: offers, puts, takes, releases and closes race.

Each round has a fresh slot. On even rounds two writers race `try_claim` and
`publish`; on odd rounds one sole writer uses `put`. A receiver tries to take,
then releases; a closer closes on some rounds. Every value is a `Tracked`
element: the ledger proves that each one is destroyed exactly once, wherever
it ends (a losing writer, the receiver, a writer kept by an earlier release, a
releaser that won it, or the slot's own destructor), and received at most once.
Per round, at most one writer wins, and a value is owned by at most one party.

It also checks `_CellGuard`: a write through the guarded value as the guard's
final use still runs with the lock held.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.os import getenv
from std.time import monotonic
from std.sys import stderr
from fp._internal.cells import _Cell, _lock_cell
from fp._internal.oneshot import _OneShot, _CLAIMED, _FULL
from fp.effects._async.scheduling.random import _Random
from fp.effects import Fiber
from wstp_support import check, Ledger, Tracked, WstpJob, WstpThread, wstp_start

comptime WRITER_A = 0
comptime WRITER_B = 1
comptime RECEIVER = 2
comptime CLOSER = 3


struct Rig(Movable):
    var shots: List[_OneShot[Tracked]]
    # Per round: writers that won, and parties that ended owning the value.
    var wins: List[Atomic[Int]]
    var owners: List[Atomic[Int]]
    # How values ended: taken, won by a release, kept by their writer.
    var fates: List[Atomic[Int]]

    def __init__(out self, rounds: Int):
        self.shots = List[_OneShot[Tracked]]()
        self.wins = List[Atomic[Int]]()
        self.owners = List[Atomic[Int]]()
        self.fates = List[Atomic[Int]]()
        for _ in range(3):
            self.fates.append(Atomic(0))
        for _ in range(rounds):
            self.shots.append(_OneShot[Tracked]())
            self.wins.append(Atomic(0))
            self.owners.append(Atomic(0))


def jitter(mut random: _Random):
    var end = Int(monotonic()) + random.below(400)
    while Int(monotonic()) < end:
        pass


@fieldwise_init
struct Party(WstpJob):
    var rig: ArcPointer[Rig]
    var ledger: Ledger
    var role: Int
    var rounds: Int

    def work(deinit self):
        var random = _Random(UInt64(self.role * 7919 + 13))
        self.ledger.arrive_and_wait()
        for r in range(self.rounds):
            ref shot = self.rig[].shots[r]
            if random.below(4) == 0:
                jitter(random)
            if self.role == WRITER_A or self.role == WRITER_B:
                var sole = r % 2 == 1
                if sole and self.role == WRITER_B:
                    continue
                var item = self.ledger.make(2 * r + self.role)
                if sole:
                    var back = shot.put(item^)
                    if back:
                        _ = self.rig[].owners[r].fetch_add(1)
                        _ = self.rig[].fates[2].fetch_add(1)
                        self.ledger.receive(back.take())
                    else:
                        _ = self.rig[].wins[r].fetch_add(1)
                elif shot.try_claim():
                    _ = self.rig[].wins[r].fetch_add(1)
                    var kept = shot.publish(item^)
                    if kept:
                        _ = self.rig[].owners[r].fetch_add(1)
                        _ = self.rig[].fates[2].fetch_add(1)
                        self.ledger.receive(kept.take())
                # A losing writer's value is destroyed here, unreceived.
            elif self.role == RECEIVER:
                var taken = Optional[Tracked]()
                for _ in range(random.below(64)):
                    taken = shot.take()
                    if taken:
                        break
                if taken:
                    _ = self.rig[].owners[r].fetch_add(1)
                    _ = self.rig[].fates[0].fetch_add(1)
                    self.ledger.receive(taken.take())
                    # Releasing after a take keeps nothing.
                    check(not shot.release(), "release after take")
                else:
                    var won = shot.release()
                    if won:
                        _ = self.rig[].owners[r].fetch_add(1)
                        _ = self.rig[].fates[1].fetch_add(1)
                        self.ledger.receive(won.take())
            else:
                if r % 3 == 0:
                    _ = shot.close()


def races(rounds: Int) raises -> List[Int]:
    """One run; returns how many values were taken, won by a release, and kept by writers."""
    var ledger = Ledger(2 * rounds)
    var rig = ArcPointer(Rig(rounds))
    var threads = List[Fiber[WstpThread[Party]]]()
    for role in range(4):
        threads.append(wstp_start(Party(rig.copy(), ledger.copy(), role, rounds)))
    ledger.open_when_ready(4)
    while threads:
        _ = threads.pop().join()
    var left_in_slots = 0
    for r in range(rounds):
        var wins = rig[].wins[r].load()
        var owners = rig[].owners[r].load()
        check(wins <= 1, "at most one writer wins a round")
        check(owners <= 1, "at most one party owns a round's value")
        var state = rig[].shots[r].state()
        if state & _FULL and owners == 0:
            left_in_slots += 1
        if r % 3 != 0:
            check(Bool(state & _CLAIMED), "an unclosed round is claimed")
    var fates: List[Int] = [rig[].fates[0].load(), rig[].fates[1].load(), rig[].fates[2].load()]
    _ = rig^
    # Every element made: destroyed once; received at most once. Odd rounds
    # have one writer, so their second id is never made.
    for r in range(rounds):
        ledger.verify_one("one-shot", 2 * r, False)
        if r % 2 == 0:
            ledger.verify_one("one-shot", 2 * r + 1, False)
    check(ledger.received() + left_in_slots <= rounds, "each round's value has one fate")
    return fates^


def guard_holds_lock():
    var cell = _Cell(Atomic(UInt8(0)), Optional(List[Int]()))
    var observer = Pointer(to=cell.lock).unsafe_origin_cast[MutUntrackedOrigin]()
    var guard = _lock_cell(cell)
    # The guard's final use is the write: the lock must still be held during it.
    guard.value().append(Int(observer[].load()))
    check(cell.slot.value()[0] == 1, "a guard's final use runs under the lock")
    check(cell.lock.load() == 0, "the lock is released afterwards")


def fates_in_order():
    """Force each fate on one thread, so coverage never depends on the race's timing."""
    var taken = _OneShot[Int]()
    check(not taken.put(1), "a put into a fresh slot publishes")
    var got = taken.take()
    check(Bool(got) and got.value() == 1, "the receiver takes a published value")
    var released = _OneShot[Int]()
    check(not released.put(2), "a put publishes")
    var won = released.release()
    check(Bool(won) and won.value() == 2, "a release after publication wins the value")
    var early = _OneShot[Int]()
    check(not early.release(), "a release of an empty slot wins nothing")
    var back = early.put(3)
    check(Bool(back) and back.value() == 3, "a sole writer after a release keeps its value")
    var claimed = _OneShot[Int]()
    check(not claimed.release(), "a release of an empty slot wins nothing")
    check(claimed.try_claim(), "a claim after a release succeeds")
    var kept = claimed.publish(4)
    check(Bool(kept) and kept.value() == 4, "a publish after a release returns the value to its writer")
    var closed = _OneShot[Int]()
    _ = closed.close()
    check(not closed.try_claim(), "a closed slot refuses claims")


def main() raises:
    var scale = 1
    var text = getenv("WSTP_SCALE")
    if text:
        scale = Int(text)
    guard_holds_lock()
    fates_in_order()
    var fates: List[Int] = [0, 0, 0]
    for _ in range(4):
        var seen = races(20_000 * scale)
        for i in range(3):
            fates[i] += seen[i]
    # Which fates the race reaches depends on thread timing: a receiver that runs
    # ahead releases every slot, one that lags takes them all. The race checks
    # exactly-once ownership; fates_in_order covers each fate deterministically.
    print("race oneshot: taken", fates[0], "won by release", fates[1], "kept by writer", fates[2], file=stderr)
    print("race oneshot: offers, puts, takes, releases and closes on four threads, each value destroyed once; guards hold their lock")
