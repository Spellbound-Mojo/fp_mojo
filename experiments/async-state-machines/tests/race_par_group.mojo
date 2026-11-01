"""AsyncPar's completion group on OS threads: announcements race the waiter's takes.

Four announcer threads each announce their share of the nodes; every other
node is also announced by a second thread, as a refused child is by both its
finalizer and its parent, so announcing must push exactly once. The main
thread is the waiter: it reads the signal's revision, takes every
announcement, and when it got nothing waits only for the revision to change,
as the waiting leaf does. Only the push that makes the stack non-empty
notifies, so a lost wake hangs the waiter and fails the run on its timeout.
Every node must be received exactly once.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.os import getenv
from std.sys import stderr
from fp.effects import Fiber
from fp.effects._async.engine import _ParGroup, _ParNode
from wstp_support import check, Ledger, WstpJob, WstpThread, wstp_start

comptime ANNOUNCERS = 4


@fieldwise_init
struct Announcer(WstpJob):
    var group: ArcPointer[_ParGroup]
    var nodes: List[ArcPointer[_ParNode]]
    var ledger: Ledger

    def work(deinit self):
        self.ledger.arrive_and_wait()
        for index in range(len(self.nodes)):
            self.group[].finished(self.nodes[index].copy())


def round(count: Int) raises -> Int:
    """Runs one round; returns how many times the waiter found nothing and waited."""
    var group = ArcPointer(_ParGroup())
    var shares = List[List[ArcPointer[_ParNode]]]()
    for _ in range(ANNOUNCERS):
        shares.append(List[ArcPointer[_ParNode]]())
    for index in range(count):
        var node = ArcPointer(_ParNode(index))
        shares[index % ANNOUNCERS].append(node.copy())
        if index % 2 == 0:
            # A second announcer for the same node.
            shares[(index + 1) % ANNOUNCERS].append(node.copy())
    var ledger = Ledger(0)
    var threads = List[Fiber[WstpThread[Announcer]]]()
    while shares:
        threads.append(wstp_start(Announcer(group.copy(), shares.pop(), ledger.copy())))
    ledger.open_when_ready(ANNOUNCERS)
    var seen = List[Int](length=count, fill=0)
    var received = 0
    var waits = 0
    while received < count:
        var revision = group[].signal.revision()
        var taken = group[].take()
        if not len(taken):
            waits += 1
            while group[].signal.revision() == revision:
                pass
            continue
        for index in range(len(taken)):
            var position = taken[index].node[].index
            check(seen[position] == 0, "a node is received once")
            seen[position] = 1
            received += 1
    while threads:
        _ = threads.pop().join()
    check(not len(group[].take()), "nothing is announced twice")
    return waits


def main() raises:
    var scale = 1
    var text = getenv("WSTP_SCALE")
    if text:
        scale = Int(text)
    var waits = 0
    for _ in range(12):
        waits += round(20_000 * scale)
    print("race par group: waits", waits, file=stderr)
    print("race par group: announcements on four threads race the waiter; each node received once, no wake lost")
