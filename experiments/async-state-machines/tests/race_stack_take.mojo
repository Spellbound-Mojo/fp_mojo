"""The closable stack's `take_all` and `push_first` on OS threads, racing pushes and a close.

Three pusher threads push their own elements with `push_first`, counting the
pushes that report making the stack non-empty. A taker thread detaches
everything with `take_all` in a loop, counting the non-empty takes. The main
thread closes the stack at a random moment in most rounds; in the last round
it never closes and takes what is left after the others stop.

- Every element is received exactly once: by a take, by the close, or back
  from a push the closed stack refused.
- Every empty-to-non-empty transition has exactly one first push: the first
  pushes equal the non-empty detaches (takes, the close, the final take).
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.os import getenv
from std.time import monotonic
from std.sys import stderr
from fp._internal.closable_stack import _ClosableStack, _StackLink, _Linked
from fp.effects import Fiber
from fp.effects._async.scheduling.random import _Random
from wstp_support import check, Ledger, Tracked, WstpJob, WstpThread, wstp_start

comptime PUSHERS = 3


struct TakeBox(Movable):
    """An element's allocation, embedding its stack link."""
    var link: _StackLink[TakeItem]
    var tracked: Optional[Tracked]

    def __init__(out self, var tracked: Tracked):
        self.link = _StackLink[TakeItem]()
        self.tracked = Optional(tracked^)


struct TakeItem(_Linked):
    """The only handle to one `Tracked` element's box."""
    var box: ArcPointer[TakeBox]

    def __init__(out self, var tracked: Tracked):
        self.box = ArcPointer(TakeBox(tracked^))

    def _link_address(self) -> Int:
        return Int(Pointer(to=self.box[].link))

    def into_tracked(deinit self) -> Tracked:
        var box = self.box^
        return box[].tracked.take()


struct TakeRig(Movable):
    var stack: _ClosableStack[TakeItem]
    var stop: Atomic[Int]
    var firsts: Atomic[Int]
    var takes: Atomic[Int]
    var refused: Atomic[Int]

    def __init__(out self):
        self.stack = _ClosableStack[TakeItem]()
        self.stop = Atomic(0)
        self.firsts = Atomic(0)
        self.takes = Atomic(0)
        self.refused = Atomic(0)


def receive_all(var items: List[TakeItem], ledger: Ledger) -> Bool:
    var any = len(items) > 0
    while items:
        ledger.receive(items.pop().into_tracked())
    return any


@fieldwise_init
struct TakePusher(WstpJob):
    var rig: ArcPointer[TakeRig]
    var ledger: Ledger
    var index: Int
    var count: Int

    def work(deinit self):
        self.ledger.arrive_and_wait()
        for i in range(self.count):
            var first = False
            var refused = self.rig[].stack.push_first(TakeItem(self.ledger.make(i * PUSHERS + self.index)), first)
            if refused:
                check(not first, "a refused push is never first")
                _ = self.rig[].refused.fetch_add(1)
                self.ledger.receive(refused.take().into_tracked())
            elif first:
                _ = self.rig[].firsts.fetch_add(1)


@fieldwise_init
struct Taker(WstpJob):
    var rig: ArcPointer[TakeRig]
    var ledger: Ledger

    def work(deinit self):
        self.ledger.arrive_and_wait()
        while self.rig[].stop.load[ordering=Ordering.ACQUIRE]() == 0:
            if receive_all(self.rig[].stack.take_all(), self.ledger):
                _ = self.rig[].takes.fetch_add(1)


def round(per_pusher: Int, seed: UInt64, closes: Bool) raises -> Int:
    """Runs one round; returns the refused pushes."""
    var total = per_pusher * PUSHERS
    var ledger = Ledger(total)
    var rig = ArcPointer(TakeRig())
    var random = _Random(seed)
    var pushers = List[Fiber[WstpThread[TakePusher]]]()
    for index in range(PUSHERS):
        pushers.append(wstp_start(TakePusher(rig.copy(), ledger.copy(), index, per_pusher)))
    var taker = wstp_start(Taker(rig.copy(), ledger.copy()))
    ledger.open_when_ready(PUSHERS + 1)
    var detaches = 0
    if closes:
        var end = Int(monotonic()) + random.below(2_000_000)
        while Int(monotonic()) < end:
            pass
        if receive_all(rig[].stack.close(), ledger):
            detaches += 1
        check(rig[].stack.is_closed() and not rig[].stack.take_all(), "a closed stack takes nothing")
    while pushers:
        _ = pushers.pop().join()
    rig[].stop.store[ordering=Ordering.RELEASE](1)
    _ = taker^.join()
    if not closes and receive_all(rig[].stack.take_all(), ledger):
        detaches += 1
    detaches += rig[].takes.load()
    check(rig[].firsts.load() == detaches, String("one first push per transition: ", rig[].firsts.load(), " firsts, ", detaches, " non-empty detaches"))
    var refusals = rig[].refused.load()
    _ = rig^
    ledger.verify("take", True)
    return refusals


def main() raises:
    var scale = 1
    var text = getenv("WSTP_SCALE")
    if text:
        scale = Int(text)
    var refused = 0
    for r in range(12):
        refused += round(20_000 * scale, UInt64(r + 1), r != 11)
    print("race stack take: refused", refused, file=stderr)
    print("race stack take: take_all and push_first race pushes and a close; every element once, one first push per transition")
