"""The fiber record's protocol on three OS threads: complete, join, claim drop and dropped deliveries.

Each round has a fresh record. A completer thread publishes its outcome, a
success or a failure, while the claim is held by either a joiner thread or a
dropper thread:

- the joiner waits until the record is done, then takes the outcome through a
  delivery and either uses it or drops the delivery, as cancellation does;
- the dropper drops the claim at a random moment, before or after completion.

Successes and errors carry `Tracked` elements. The ledger proves that every
outcome is destroyed exactly once, and that every failure is either joined or
reported, exactly once: errors record their own reporting when the reporter
formats them.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.os import getenv, abort
from std.time import monotonic
from std.sys import stderr
from fp.data import Result, Ok, Err, NonEmptyList
from fp.effects import Fiber, Outcome, EffectFailure
from fp._internal.erased import _Erased
from fp.effects._async.fibers import _FiberRecord, _Claim, _Delivery
from fp.effects._async.scheduling.random import _Random
from wstp_support import check, Ledger, Tracked, WstpJob, WstpThread, wstp_start


def quiet(line: String):
    pass


struct Fault(Movable, Writable):
    """A move-only error that marks itself when the reporter formats it."""
    var item: Optional[Tracked]
    var reported: Pointer[Atomic[Int], MutUntrackedOrigin]

    def __init__(out self, var item: Tracked, reported: Pointer[Atomic[Int], MutUntrackedOrigin]):
        self.item = Optional(item^)
        self.reported = reported

    def write_to(self, mut writer: Some[Writer]):
        _ = self.reported[].fetch_add(1)
        writer.write("fault")


struct Rig(Movable):
    var records: List[ArcPointer[_FiberRecord[Fault]]]
    var reported: List[Atomic[Int]]
    var joined: List[Atomic[Int]]

    def __init__(out self, rounds: Int):
        self.records = List[ArcPointer[_FiberRecord[Fault]]]()
        self.reported = List[Atomic[Int]]()
        self.joined = List[Atomic[Int]]()
        for _ in range(rounds):
            self.records.append(ArcPointer(_FiberRecord[Fault](True, quiet)))
            self.reported.append(Atomic(0))
            self.joined.append(Atomic(0))

    def reported_at(mut self, r: Int) -> Pointer[Atomic[Int], MutUntrackedOrigin]:
        return Pointer(to=self.reported[r]).unsafe_origin_cast[MutUntrackedOrigin]()


def jitter(mut random: Random):
    var end = Int(monotonic()) + random.below(800)
    while Int(monotonic()) < end:
        pass


comptime Random = _Random


@fieldwise_init
struct Completer(WstpJob):
    var rig: ArcPointer[Rig]
    var ledger: Ledger
    var rounds: Int

    def work(deinit self):
        var random = Random(UInt64(7))
        self.ledger.arrive_and_wait()
        for r in range(self.rounds):
            if random.below(3) == 0:
                jitter(random)
            var outcome: Outcome[_Erased, Fault]
            if r % 2 == 0:
                outcome = Optional(Result[_Erased, EffectFailure[Fault]](Ok(_Erased(self.ledger.make(r)))))
            else:
                var fault = Fault(self.ledger.make(r), self.rig[].reported_at(r))
                outcome = Optional(Result[_Erased, EffectFailure[Fault]](Err(EffectFailure[Fault](NonEmptyList(fault^), False))))
            self.rig[].records[r][].complete(outcome^)


struct Holder(WstpJob):
    """Holds the claims of its rounds; joins them (joiner) or drops them (dropper)."""
    var rig: ArcPointer[Rig]
    var ledger: Ledger
    # Claims in reverse round order, so popping yields round order.
    var claims: List[_Claim[Fault]]
    var rounds: List[Int]
    var joiner: Bool

    def __init__(out self, rig: ArcPointer[Rig], ledger: Ledger, var claims: List[_Claim[Fault]], var rounds: List[Int], joiner: Bool):
        self.rig = rig.copy()
        self.ledger = ledger.copy()
        self.claims = claims^
        self.rounds = rounds^
        self.joiner = joiner

    def work(deinit self):
        var random = Random(UInt64(11 if self.joiner else 13))
        self.ledger.arrive_and_wait()
        while self.claims:
            var claim = self.claims.pop()
            var r = self.rounds.pop()
            if random.below(3) == 0:
                jitter(random)
            if not self.joiner:
                # Dropped before or after completion: the release decides.
                _ = claim^
                continue
            ref record = self.rig[].records[r][]
            while not record.done():
                pass
            var delivery = _Delivery[Fault](claim^)
            if random.below(2) == 0:
                # A canceled join drops its delivery: the failure is reported.
                _ = delivery^
                continue
            var outcome = delivery^.take()
            _ = self.rig[].joined[r].fetch_add(1)
            var result = outcome.take()
            if result.is_ok():
                self.ledger.receive(result^._take_ok().take[Tracked]())
            else:
                var faults = result^._take_err().into_errors().into_list()
                var fault = faults.pop()
                self.ledger.receive(fault.item.take())


def races(rounds: Int) raises -> Tuple[Int, Int]:
    """One run; returns the failures joined and the failures reported."""
    var ledger = Ledger(rounds)
    var rig = ArcPointer(Rig(rounds))
    var join_claims = List[_Claim[Fault]]()
    var join_rounds = List[Int]()
    var drop_claims = List[_Claim[Fault]]()
    var drop_rounds = List[Int]()
    for r in range(rounds - 1, -1, -1):
        if (r // 2) % 3 == 2:
            drop_claims.append(_Claim[Fault](rig[].records[r].copy()))
            drop_rounds.append(r)
        else:
            join_claims.append(_Claim[Fault](rig[].records[r].copy()))
            join_rounds.append(r)
    var completer = wstp_start(Completer(rig.copy(), ledger.copy(), rounds))
    var joiner = wstp_start(Holder(rig.copy(), ledger.copy(), join_claims^, join_rounds^, True))
    var dropper = wstp_start(Holder(rig.copy(), ledger.copy(), drop_claims^, drop_rounds^, False))
    ledger.open_when_ready(3)
    _ = completer^.join()
    _ = joiner^.join()
    _ = dropper^.join()
    var joins = 0
    var reports = 0
    for r in range(rounds):
        check(rig[].records[r][].done(), "every record completed")
        if r % 2 == 1:
            joins += rig[].joined[r].load()
            reports += rig[].reported[r].load()
        if r % 2 == 1:
            var fates = rig[].reported[r].load() + rig[].joined[r].load()
            if fates != 1:
                abort(String("race record: failure ", r, " joined ", rig[].joined[r].load(), " and reported ", rig[].reported[r].load(), " times"))
    _ = rig^
    ledger.verify("record", False)
    return (joins, reports)


def main() raises:
    var scale = 1
    var text = getenv("WSTP_SCALE")
    if text:
        scale = Int(text)
    var joins = 0
    var reports = 0
    for _ in range(4):
        var seen = races(20_000 * scale)
        joins += seen[0]
        reports += seen[1]
    check(joins > 0 and reports > 0, "failures were both joined and reported")
    print("race record: failures joined", joins, "reported", reports, file=stderr)
    print("race record: completion, joins, claim drops and dropped deliveries on three threads; each failure joined or reported once")
