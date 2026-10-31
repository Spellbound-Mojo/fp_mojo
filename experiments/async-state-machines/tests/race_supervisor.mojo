"""Supervisor starts racing release: scopes on OS threads, then late supervision on the runtime.

Part one drives a supervisor's scope directly from OS threads, as fibers on
several workers will. Three threads adopt fresh fiber records, prune as they
go, and complete some of their children; the main thread closes the scope at a
random moment, as release does: canceling the live children, or, when it
awaits them, leaving them running. Every adoption is either refused, and then
uncounted, or listed exactly once: in the close's list, or as an orphan of a
concurrent prune. At the end, every accepted child that did not complete was
canceled exactly when the close cancels, and the live count matches.

Part two runs on the runtime: a supervisor kept past its scope supervises
again. The fiber it returns is already canceled, its join yields a
cancellation, and its program never runs, with and without awaiting release.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.os import getenv, abort
from std.time import monotonic
from std.sys import stderr
from fp.callables import OnceUnary
from fp.effects import Fiber as Thread, Outcome
from fp.effects.async_runtime import IO, Fiber, Supervisor, run
from fp.effects._async.fibers import _FiberRecord, _Scope, _CLOSE_CANCEL, _CLOSE_KEEP
from fp._internal.erased import _Erased
from fp.effects._async.scheduling.random import _Random
from wstp_support import check, WstpJob, WstpThread, wstp_start

comptime ADOPTERS = 3

comptime Record = ArcPointer[_FiberRecord[Int]]


struct Rig(Movable):
    var scope: _Scope[Int]
    var ready: Atomic[Int]
    var go: Atomic[Int]
    var completed: Atomic[Int]

    def __init__(out self):
        self.scope = _Scope[Int]()
        self.ready = Atomic(0)
        self.go = Atomic(0)
        self.completed = Atomic(0)


struct Adopter(WstpJob):
    var rig: ArcPointer[Rig]
    var index: Int
    var count: Int
    # Accepted children; refused ones are counted.
    var accepted: ArcPointer[List[Record]]
    var refused: ArcPointer[Atomic[Int]]

    def __init__(out self, rig: ArcPointer[Rig], index: Int, count: Int, accepted: ArcPointer[List[Record]], refused: ArcPointer[Atomic[Int]]):
        self.rig = rig.copy()
        self.index = index
        self.count = count
        self.accepted = accepted.copy()
        self.refused = refused.copy()

    def work(deinit self):
        var random = _Random(UInt64(self.index + 31))
        _ = self.rig[].ready.fetch_add(1)
        while self.rig[].go.load[ordering=Ordering.ACQUIRE]() == 0:
            pass
        for _ in range(self.count):
            var record = ArcPointer(_FiberRecord[Int]())
            if not self.rig[].scope.adopt(record):
                _ = self.refused[].fetch_add(1)
                continue
            if random.below(2) == 0:
                # The child completes on this thread, as on its own worker.
                record[].complete(Outcome[_Erased, Int]())
                self.rig[].scope.child_completed()
                _ = self.rig[].completed.fetch_add(1)
            self.accepted[].append(record^)





def scope_round(per_thread: Int, seed: UInt64, tag: UInt8) raises -> Tuple[Int, Int]:
    """One round; returns the refused adoptions and the children live at the close."""
    var rig = ArcPointer(Rig())
    var random = _Random(seed)
    var lists = List[ArcPointer[List[Record]]]()
    var refusals = List[ArcPointer[Atomic[Int]]]()
    var threads = List[Thread[WstpThread[Adopter]]]()
    for index in range(ADOPTERS):
        lists.append(ArcPointer(List[Record]()))
        refusals.append(ArcPointer(Atomic(0)))
        threads.append(wstp_start(Adopter(rig.copy(), index, per_thread, lists[index], refusals[index])))
    while rig[].ready.load() < ADOPTERS:
        pass
    rig[].go.store[ordering=Ordering.RELEASE](1)
    var end = Int(monotonic()) + random.below(3_000_000)
    while Int(monotonic()) < end:
        pass
    var closed = List[Record]()
    if tag == _CLOSE_CANCEL:
        rig[].scope.cancel_children()
    else:
        closed = rig[].scope.close(tag)
    check(not rig[].scope.adopt(ArcPointer(_FiberRecord[Int]())), "a closed scope refuses children")
    while threads:
        _ = threads.pop().join()
    var accepted = 0
    var refused = 0
    var live = 0
    for index in range(ADOPTERS):
        refused += refusals[index][].load()
        for record in lists[index][]:
            accepted += 1
            if record[].done():
                continue
            live += 1
            # Live at the close: canceled exactly when the close cancels.
            if record[].token.requested() != (tag == _CLOSE_CANCEL):
                abort("race supervisor: a live child's cancellation does not match the close")
    check(accepted + refused == ADOPTERS * per_thread, "every adoption is accepted or refused")
    check(rig[].scope.count() == accepted - rig[].completed.load(), "refused children are uncounted")
    check(refused > 0 or accepted == ADOPTERS * per_thread, "refusals follow the close")
    _ = closed^
    return (refused, live)


@fieldwise_init
struct Mark(OnceUnary):
    var marks: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        self.marks[] += 1
        return value


@fieldwise_init
struct Keep(OnceUnary):
    """The body: return the supervisor itself, so it outlives its scope."""
    comptime Arg = Supervisor[Int]
    comptime Out = IO[Supervisor[Int], Int]

    def call_once(deinit self, var supervisor: Supervisor[Int]) -> IO[Supervisor[Int], Int]:
        return IO[Supervisor[Int], Int].pure(supervisor^)


@fieldwise_init
struct SuperviseLate(OnceUnary):
    var marks: ArcPointer[Int]
    comptime Arg = Supervisor[Int]
    comptime Out = IO[Outcome[Int, Int], Int]

    def call_once(deinit self, var supervisor: Supervisor[Int]) -> IO[Outcome[Int, Int], Int]:
        return supervisor.supervise(IO[Int, Int].pure(5).map(Mark(self.marks^))).flat_map(JoinLate())


@fieldwise_init
struct JoinLate(OnceUnary):
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Outcome[Int, Int], Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Outcome[Int, Int], Int]:
        return fiber^.join()


def late_supervision(await_on_release: Bool):
    var marks = ArcPointer(0)
    var program = Supervisor[Int].scoped(Keep(), await_on_release).flat_map(SuperviseLate(marks.copy()))
    var outcome = run(program^)
    check(Bool(outcome) and outcome.value().is_ok(), "supervising after release does not fail the caller")
    var joined = outcome.take()._take_ok()
    check(not joined, "a fiber supervised after release is already canceled")
    check(marks[] == 0, "its program never runs")


def main() raises:
    var scale = 1
    var text = getenv("WSTP_SCALE")
    if text:
        scale = Int(text)
    var refused = 0
    var live = 0
    for r in range(16):
        var seen = scope_round(10_000 * scale, UInt64(r + 1), _CLOSE_CANCEL if r % 2 == 0 else _CLOSE_KEEP)
        refused += seen[0]
        live += seen[1]
    check(refused > 0 and live > 0, "adoptions raced the close, and live children were closed")
    print("race supervisor: refused", refused, "live at close", live, file=stderr)
    late_supervision(False)
    late_supervision(True)
    print("race supervisor: adoption races release on four threads; supervising after release yields a canceled fiber that never runs")
