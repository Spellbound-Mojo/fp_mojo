"""Scoped exit borrowing, suspended finalizers, exact errors and destruction."""
from std.memory import ArcPointer
from fp.effects import IOContext, ExitCase, CancellationToken
from state_machine import Machine, ScopedMachine, Step, Wait, Signal, Driver, guarantee, guarantee_case, on_cancel, pure, run
from foundation import check, success, failure, Resource, Failure
from children import Terminal


@fieldwise_init
struct InspectExit(ScopedMachine):
    var stats: ArcPointer[List[Int]]
    var gate: Signal
    var body_failed: Bool
    var body_canceled: Bool
    var fail: Bool
    comptime Input = ExitCase[Failure]
    comptime Value = Resource
    comptime Error = Failure
    def poll[o: ImmOrigin](mut self, ref[o] exit: Self.Input, context: IOContext[Failure]) -> Step[Resource, Failure]:
        check(context._masked and not context.canceled(), "finalizer is masked")
        check(exit.is_error() == self.body_failed and exit.is_canceled() == self.body_canceled, "exact entry exit case remains stable across polls")
        if self.body_failed:
            check(exit.failure().value().errors.first().code == 11, "borrow original move-only body error")
        self.stats[][2] += 1
        if self.stats[][2] == 1:
            return .pending(Wait.changed(self.gate, self.gate.revision()))
        if self.fail:
            return failure[Resource](33, self.stats)
        return success[Resource, Failure](Resource(String("discarded finalizer result"), self.stats.copy()))


def matrix(mode: Int, parent_cancel: Bool, cleanup_fail: Bool):
    var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
    var body = Signal()
    var gate = Signal()
    var body_fail = mode == 1 or mode == 3
    var canceled = mode >= 2 or parent_cancel
    var driver = Driver(guarantee_case(Terminal(body.copy(), stats.copy(), 0, mode, False), InspectExit(stats.copy(), gate.copy(), body_fail, canceled, cleanup_fail)))
    check(not driver.poll(100).runnable, "entered body parks")
    if parent_cancel:
        driver.cancel()
    body.notify()
    check(not driver.poll(100).runnable and stats[][2] == 1, "finalizer suspends once")
    if parent_cancel:
        driver.cancel()
    check(driver.poll(100).polls == 0, "masked finalizer remains parked")
    var moved = driver^
    gate.notify()
    check(moved.poll(100).completed and stats[][2] == 2, "moved finalizer drains")
    var outcome = moved^.finish()
    var errors = Int(body_fail) + Int(cleanup_fail)
    if errors:
        var failed = outcome.take()._take_err()
        check(failed.canceled == canceled, "independent cancellation retained")
        var retained = failed^.into_errors().into_list()
        check(len(retained) == errors and retained[0].code == (11 if body_fail else 33), "body error precedes finalizer error")
        if errors == 2:
            check(retained[1].code == 33, "finalizer error follows body error")
        _ = retained^
    elif canceled:
        check(not outcome, "canceled body stays canceled")
    else:
        check(outcome.take()._take_ok() == 0, "body result preserved")
    check(stats[][4] == errors and stats[][3] == Int(not cleanup_fail), "all error and discarded result owners destroyed once")


@fieldwise_init
struct CountCleanup(Machine):
    var stats: ArcPointer[List[Int]]
    comptime Value = Resource
    comptime Error = Failure
    def poll(mut self, context: IOContext[Failure]) -> Step[Resource, Failure]:
        check(context._masked, "on_cancel cleanup masked")
        self.stats[][2] += 1
        return success[Resource, Failure](Resource(String("discarded"), self.stats.copy()))


def cancellation_only():
    for mode in range(4):
        var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
        var gate = Signal()
        var driver = Driver(on_cancel(Terminal(gate.copy(), stats.copy(), 0, mode, False), CountCleanup(stats.copy())))
        _ = driver.poll(100)
        gate.notify()
        check(driver.poll(100).completed, "on_cancel finishes")
        _ = driver^.finish()
        check(stats[][2] == Int(mode >= 2) and stats[][3] == Int(mode >= 2), "only observed cancellation invokes cleanup")


def owned_results():
    var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
    var unopened = guarantee(pure[Failure](Resource(String("body"), stats.copy())), pure[Failure](Resource(String("cleanup"), stats.copy())))
    _ = unopened^
    check(stats[][3] == 2, "unopened recipes drop both owners without execution")
    var token = CancellationToken()
    token.cancel()
    check(not run(guarantee(pure[Failure](Resource(String("body"), stats.copy())), CountCleanup(stats.copy())), token), "pre-canceled wrapper stays unopened")
    check(stats[][3] == 3 and stats[][2] == 0, "no finalizer for unopened execution")
    var gate = Signal()
    var driver = Driver(guarantee_case(pure[Failure](Resource(String("retained body"), stats.copy())), InspectExit(stats.copy(), gate.copy(), False, False, False)))
    check(not driver.poll(100).runnable and stats[][3] == 3, "body owner lives through suspended finalizer")
    driver.cancel()
    check(driver.poll(100).polls == 0 and stats[][3] == 3, "late cancellation waits for cleanup")
    gate.notify()
    check(driver.poll(100).completed, "late cancellation drains cleanup")
    check(not driver^.finish() and stats[][3] == 5, "body and finalizer results destroyed exactly once")


@fieldwise_init
struct Fail(Machine):
    var code: Int
    var stats: ArcPointer[List[Int]]
    comptime Value = Int
    comptime Error = Failure
    def poll(mut self, context: IOContext[Failure]) -> Step[Int, Failure]:
        return failure[Int](self.code, self.stats)


def nested_errors():
    var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
    var outcome = run(guarantee(guarantee(Fail(11, stats.copy()), Fail(22, stats.copy())), Fail(33, stats.copy())))
    var errors = outcome.take()._take_err().into_errors().into_list()
    check(len(errors) == 3 and errors[0].code == 11 and errors[1].code == 22 and errors[2].code == 33, "nested finalizers retain body-to-outer error order")
    _ = errors^
    check(stats[][4] == 3, "nested errors destroyed once")


def main():
    for mode in range(4):
        for cancel in range(2):
            for fail in range(2):
                matrix(mode, Bool(cancel), Bool(fail))
    cancellation_only()
    owned_results()
    nested_errors()
    print("async finalization: 16 exit cases, scoped error borrowing, suspended cleanup, on_cancel, owned results")
