"""Checked host inputs retain the linear owner before and after entry."""
from std.memory import ArcPointer
from fp.effects import IOContext, EffectFailure
from fp.data import Result, Ok
from fp.effects._async.family import Async, Machine
from fp.effects._async.application import pure, Pure
from fp.effects._async.kernel import Step, Wait
from fp.effects._async.host import Driver, Nursery, run
from foundation import check


@fieldwise_init
struct Source(Machine):
    comptime Family = Async[Int]
    comptime Value = Int
    comptime Error = Int
    var calls: ArcPointer[Int]
    var parked: Bool
    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        self.calls[] += 1
        if context.canceled():
            return .ready(None)
        if self.parked:
            return .pending(Wait.never())
        return .ready(Optional(Result[Int, EffectFailure[Int]](Ok(42))))


def main() raises:
    var calls = ArcPointer(0)
    var driver = Driver(Source(calls.copy(), False))
    var rejected = False
    try:
        _ = driver.poll(-1)
    except error:
        comptime assert type_of(error) == Error
        rejected = True
    check(rejected and calls[] == 0, "invalid budget retains unopened root without progress")
    try:
        var status = driver.poll(0)
        check(not status.completed and status.polls == 0, "zero only observes")
    except error:
        check(False, "zero budget must be accepted")
    while not driver.poll().completed:
        pass
    var result = driver^.finish()
    check(result.take()._take_ok() == 42 and calls[] == 1, "retained root completes")
    var parked = Driver(Source(calls.copy(), True))
    var first = parked.poll()
    check(not first.completed and not first.runnable, "entered root parks")
    rejected = False
    try:
        _ = parked.poll(-1)
    except error:
        rejected = True
    check(rejected and calls[] == 2, "invalid budget preserves entered owner and state")
    var moved = parked^
    moved.request_cancel()
    while not moved.poll().completed:
        pass
    var canceled = moved^.finish()
    check(not canceled and calls[] == 3, "moved owner wakes and drains cancellation")
    rejected = False
    try:
        _ = Nursery[Pure[Int, Int]](-1)
    except error:
        rejected = True
    check(rejected, "negative nursery admission checked before allocation")
    var nursery = Nursery[Pure[Int, Int]](0)
    var spawner = nursery.spawner()
    var returned = spawner.try_spawn(pure[Int](42))
    check(Bool(returned), "rejected child stays owned by caller")
    var retained = run(returned.take())
    check(retained.take()._take_ok() == 42, "rejected child remains executable")
    spawner.close()
    var empty = run(nursery^)
    check(len(empty.take()._take_ok()) == 0, "zero capacity closes and drains")
    print("host admission: retained linear owners, checked budgets and nursery limits, moved cancellation drain")
