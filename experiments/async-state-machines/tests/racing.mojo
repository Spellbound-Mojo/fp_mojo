"""First-terminal arbitration, loser cleanup, and deadline/fallback ownership."""
from std.memory import ArcPointer
from fp.data import Left, Right
from fp.effects import IOContext, CancellationToken
from fp._internal.cells import _lock_metadata
from state_machine import Machine, Step, Wait, Signal, Clock, Driver, Completion, callback, race, timeout_to, pure, run
from foundation import check, success, Resource, Failure
from children import Terminal, Controlled
from callbacks import Register, Withdraw


def matrix_case(left: Int, right: Int, first: Int):
    var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
    var a = Signal()
    var b = Signal()
    var driver = Driver(race(Terminal(a.copy(), stats.copy(), 0, left, False), Terminal(b.copy(), stats.copy(), 1, right, False)))
    check(not driver.poll(10).runnable, "both children park")
    if first == 0:
        a.notify()
    else:
        b.notify()
    check(driver.poll(10).completed, "winner triggers complete loser draining")
    var outcome = driver^.finish()
    check(stats[][0] == 2 and stats[][1] == 2, "each child polled only until terminal")
    var selected = left if first == 0 else right
    var losing = right if first == 0 else left
    var errors = Int(selected == 1 or selected == 3) + Int(losing == 1 or losing == 3)
    if errors:
        var failure = outcome.take()._take_err()
        check(failure.canceled == (selected >= 2), "loser cancellation does not taint selected outcome")
        var retained = failure^.into_errors().into_list()
        check(len(retained) == errors, "all errors retained")
        check(retained[0].code == (11 + first if selected == 1 or selected == 3 else 12 - first), "winner error precedes loser errors")
        if errors == 2:
            check(retained[1].code == 12 - first, "loser error follows selected error")
        _ = retained^
    elif selected == 2:
        check(not outcome, "selected cancellation wins")
    else:
        var won = outcome.take()._take_ok()
        check(won.isa[Left[Int]]() == (first == 0), "selected arm retained even for identical payload types")
    check(stats[][4] == errors, "all move-only errors destroyed once")


def suspended_loser(cancel_parent: Bool, fail_cleanup: Bool):
    var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
    var winner = Signal()
    var cleanup = Signal()
    var driver = Driver(race(Terminal(winner.copy(), stats.copy(), 0, 0, False), Controlled(Signal(), cleanup.copy(), stats.copy(), 1, fail_cleanup, 0)))
    _ = driver.poll(10)
    winner.notify()
    check(not driver.poll(10).runnable and stats[][1] == 2, "winner retained while losing cleanup parks")
    if cancel_parent:
        driver.cancel()
    check(driver.poll(10).polls == 0, "parent cancellation does not spin during losing cleanup")
    var moved = driver^
    cleanup.notify()
    check(moved.poll(10).completed, "moved race drains cleanup")
    var runtime = moved.task.context._runtime.value().copy()
    var outcome = moved^.finish()
    if fail_cleanup:
        var failure = outcome.take()._take_err()
        check(failure.errors.first().code == 41 and failure.canceled == cancel_parent, "cleanup failure retained with independent parent cancellation")
    elif cancel_parent:
        check(not outcome, "parent cancellation suppresses selected success")
    else:
        check(outcome.take()._take_ok().unwrap[Left[Int]]().into_payload() == 0, "selected success survives expected losing cancellation")
    var guard = _lock_metadata(runtime._cell)
    check(guard.cell[].slot.value().active == 0, "race retires every registration")


def ownership_and_parent_cancel():
    var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
    var owned = run(race(pure[Failure](Resource(String("left"), stats.copy())), pure[Failure](Resource(String("right"), stats.copy()))))
    check(stats[][3] == 1, "unentered losing value destroyed once")
    var selected = owned.take()._take_ok().unwrap[Left[Resource]]().into_payload()
    check(selected.text == "left", "winner transferred without copying")
    _ = selected^
    check(stats[][3] == 2, "selected owner destroyed once")
    var a = Signal()
    var b = Signal()
    var driver = Driver(race(Controlled(Signal(), a.copy(), stats.copy(), 0, True, 0), Controlled(Signal(), b.copy(), stats.copy(), 1, True, 0)))
    _ = driver.poll(10)
    driver.cancel()
    check(not driver.poll(10).runnable, "parent cancellation drains both entered children")
    b.notify()
    check(not driver.poll(10).completed, "one cleanup cannot detach the other")
    a.notify()
    check(driver.poll(10).completed, "both cleanup failures retained")
    var completed = driver^.finish()
    var failure = completed.take()._take_err()
    check(failure.canceled and failure.errors.first().code == 41, "first observed terminal orders parent-canceled failures")


def main():
    for left in range(4):
        for right in range(4):
            for first in range(2):
                matrix_case(left, right, first)
    for cancel in range(2):
        for fail in range(2):
            suspended_loser(Bool(cancel), Bool(fail))
    ownership_and_parent_cancel()
    print("racing: 32 outcome orders, loser draining, parent cancellation, ownership")
