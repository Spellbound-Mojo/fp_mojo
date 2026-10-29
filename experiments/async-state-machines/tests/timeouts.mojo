"""Deadline entry, fallback ownership, and suspended withdrawal."""
from std.memory import ArcPointer
from fp.data import Left
from fp.effects import IOContext, CancellationToken
from fp._internal.cells import _lock_metadata
from state_machine import Machine, Step, Wait, Signal, Clock, Driver, Completion, callback, race, timeout_to, pure, run
from foundation import check, success
from callbacks import Register, Withdraw


@fieldwise_init
struct Count(Machine):
    var calls: ArcPointer[Int]
    var park: Bool
    comptime Value = Int
    comptime Error = Int
    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        self.calls[] += 1
        if context.canceled():
            return .ready(None)
        if self.park:
            return .pending(Wait.never())
        return success[Int, Int](42)


def timeouts():
    var fallback_calls = ArcPointer(0)
    var early = run(timeout_to(pure[Int](7), 100, Count(fallback_calls.copy(), False)))
    check(early.take()._take_ok() == 7 and fallback_calls[] == 0, "successful work leaves fallback unopened")
    var tie = run(race(pure[Int](1), pure[Int](2)))
    check(tie.take()._take_ok().unwrap[Left[Int]]().into_payload() == 1, "initial ready tie selects left")
    var primary_calls = ArcPointer(0)
    var clock = Clock.manual(100)
    var anchored = Driver(timeout_to(Count(primary_calls.copy(), True), 10, Count(fallback_calls.copy(), False)), CancellationToken(), clock)
    _ = anchored.poll(1)
    clock.advance_to(110)
    check(anchored.poll(100).completed, "deadline starts at entry despite delayed timer polling")
    var timed = anchored^.finish()
    check(timed.take()._take_ok() == 42 and fallback_calls[] == 1, "fallback runs once after timeout")
    for parent_cancel in range(2):
        for fail_cleanup in range(2):
            var saved = ArcPointer(Optional[Completion[Int, Int]]())
            var counts = ArcPointer(List[Int]([0, 0]))
            var gate = Signal()
            var manual = Clock.manual()
            var calls = ArcPointer(0)
            var driver = Driver(timeout_to(callback(Register(saved.copy(), counts.copy(), 0, False), Withdraw(counts.copy(), gate.copy(), Bool(fail_cleanup))), 10, Count(calls.copy(), False)), CancellationToken(), manual)
            check(driver.poll(100).deadline.value() == 10, "callback parks with a live deadline")
            manual.advance_to(10)
            check(not driver.poll(100).runnable and counts[][1] == 1 and calls[] == 0, "timeout drains callback withdrawal before fallback")
            if parent_cancel:
                driver.cancel()
            check(driver.poll(100).polls == 0, "masked withdrawal remains parked")
            gate.notify()
            check(driver.poll(100).completed, "timeout drains fully")
            var runtime = driver.task.context._runtime.value().copy()
            var outcome = driver^.finish()
            if fail_cleanup:
                var failed = outcome.take()._take_err()
                check(failed.errors.first() == 33 and failed.canceled == Bool(parent_cancel), "failed withdrawal prevents fallback")
            elif parent_cancel:
                check(not outcome, "parent cancellation prevents fallback")
            else:
                check(outcome.take()._take_ok() == 42, "fallback result preserved")
            check(calls[] == Int(not parent_cancel and not fail_cleanup), "fallback entry policy")
            check(not saved[].value().complete(success[Int, Int](9).outcome()), "late callback rejected")
            var guard = _lock_metadata(runtime._cell)
            check(guard.cell[].slot.value().active == 0 and guard.cell[].slot.value().live_timers == 0, "timeout retires children and timer")


def main():
    timeouts()
    print("timeouts: entry deadlines, initial ties, fallback ownership, suspended cleanup, parent cancellation")
