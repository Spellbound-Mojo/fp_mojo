"""The closable stack on OS threads: pushes race a close and concurrent prunes.

Three pusher threads push their own elements, and two of them also prune now
and then; a fourth thread prunes in a loop. Prunes keep even ids and drop odd
ones. The main thread closes the stack at a random moment, with a random tag.
Every element is a `Tracked` value:

- a push refused by the closed stack returns the element to its pusher;
- the close returns every listed element, oldest first;
- a prune that finds the stack closed returns its survivors as orphans, with
  the close's tag.

The ledger proves that every element is destroyed exactly once and received
at most once, and that every even element, which no prune drops, is received
exactly once: no survivor is lost when a close lands during a prune. A last
round never closes, so destroying a stack destroys its elements once.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.os import getenv
from std.time import monotonic
from std.sys import stderr
from fp._internal.closable_stack import _ClosableStack
from fp.effects import Fiber
from fp.effects._async.scheduling.random import _Random
from wstp_support import check, Ledger, Tracked, WstpJob, WstpThread, wstp_start

comptime PUSHERS = 3


def keep_even(item: Tracked) -> Bool:
    return item.id % 2 == 0


struct Rig(Movable):
    var stack: _ClosableStack[Tracked]
    var tag: Atomic[Int]
    var stop: Atomic[Int]
    var refused: Atomic[Int]
    var orphans: Atomic[Int]
    var bad_tags: Atomic[Int]

    def __init__(out self):
        self.stack = _ClosableStack[Tracked]()
        self.tag = Atomic(-1)
        self.stop = Atomic(0)
        self.refused = Atomic(0)
        self.orphans = Atomic(0)
        self.bad_tags = Atomic(0)


def prune_once(rig: ArcPointer[Rig], ledger: Ledger):
    var pruned = rig[].stack.prune[keep_even]()
    if len(pruned.orphans):
        _ = rig[].orphans.fetch_add(len(pruned.orphans))
        # The close publishes its tag before closing (see the main thread).
        if Int(pruned.tag) != rig[].tag.load[ordering=Ordering.ACQUIRE]():
            _ = rig[].bad_tags.fetch_add(1)
    while pruned.orphans:
        var orphan = pruned.orphans.pop()
        check(orphan.id % 2 == 0, "orphans are survivors")
        ledger.receive(orphan^)


@fieldwise_init
struct Pusher(WstpJob):
    var rig: ArcPointer[Rig]
    var ledger: Ledger
    var index: Int
    var count: Int

    def work(deinit self):
        var random = _Random(UInt64(self.index + 101))
        self.ledger.arrive_and_wait()
        for i in range(self.count):
            var id = i * PUSHERS + self.index
            var refused = self.rig[].stack.push(self.ledger.make(id))
            if refused:
                _ = self.rig[].refused.fetch_add(1)
                self.ledger.receive(refused.take())
            if self.index > 0 and random.below(64) == 0:
                prune_once(self.rig, self.ledger)


@fieldwise_init
struct Pruner(WstpJob):
    var rig: ArcPointer[Rig]
    var ledger: Ledger

    def work(deinit self):
        self.ledger.arrive_and_wait()
        while self.rig[].stop.load[ordering=Ordering.ACQUIRE]() == 0:
            prune_once(self.rig, self.ledger)


def round(per_pusher: Int, seed: UInt64, closes: Bool) raises -> Tuple[Int, Int]:
    """Runs one round; returns the refused pushes and the orphans."""
    var total = per_pusher * PUSHERS
    var ledger = Ledger(total)
    var rig = ArcPointer(Rig())
    var random = _Random(seed)
    var pushers = List[Fiber[WstpThread[Pusher]]]()
    for index in range(PUSHERS):
        pushers.append(wstp_start(Pusher(rig.copy(), ledger.copy(), index, per_pusher)))
    var pruner = wstp_start(Pruner(rig.copy(), ledger.copy()))
    ledger.open_when_ready(PUSHERS + 1)
    if closes:
        var end = Int(monotonic()) + random.below(2_000_000)
        while Int(monotonic()) < end:
            pass
        var tag = random.below(2)
        rig[].tag.store[ordering=Ordering.RELEASE](tag)
        var closed = rig[].stack.close(UInt8(tag))
        while closed:
            ledger.receive(closed.pop())
        check(rig[].stack.is_closed() and not rig[].stack.close(), "a stack closes once")
    while pushers:
        _ = pushers.pop().join()
    rig[].stop.store[ordering=Ordering.RELEASE](1)
    _ = pruner^.join()
    check(rig[].bad_tags.load() == 0, "orphans carry the close's tag")
    var orphans = rig[].orphans.load()
    var refusals = rig[].refused.load()
    # A never-closed stack still holds its survivors; destroying it destroys them.
    _ = rig^
    if closes:
        for id in range(total):
            ledger.verify_one("stack", id, id % 2 == 0)
    else:
        check(orphans == 0, "an open stack orphans nothing")
        ledger.verify("stack", False)
    return (refusals, orphans)


def main() raises:
    var scale = 1
    var text = getenv("WSTP_SCALE")
    if text:
        scale = Int(text)
    var refused = 0
    var orphans = 0
    for r in range(12):
        var seen = round(20_000 * scale, UInt64(r + 1), r != 11)
        refused += seen[0]
        orphans += seen[1]
    check(refused > 0, "some pushes lost the race with the close")
    print("race stack: refused", refused, "orphans", orphans, file=stderr)
    print("race stack: pushes, prunes and a close on four threads; survivors never lost, every element destroyed once")
