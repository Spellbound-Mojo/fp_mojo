"""Lexical restoration across suspension, nested masks, children and cleanup."""
from std.memory import ArcPointer
from fp.callables import OnceUnary
from fp.effects import CancellationToken, IOContext, ExitCase
from fp._internal.cells import _lock_metadata
from state_machine import Machine, Step, Wait, Signal, Driver, Clock, Sleep, Pure, Both, Guarantee, Masked, Poll, both, pure, guarantee, uncancelable, uncancelable_with, run
from state_machine.scopes import _ProgramUse
from state_machine.finalization import _ConstantMask
from foundation import check, success


@fieldwise_init
struct Park(Machine):
    var calls: ArcPointer[Int]
    comptime Value = Int
    comptime Error = Int
    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        self.calls[] += 1
        if context.canceled():
            return .ready(None)
        return .pending(Wait.never())


@fieldwise_init
struct Active(OnceUnary):
    var calls: ArcPointer[Int]
    var saved: ArcPointer[Optional[Poll[Int]]]
    comptime Arg = Poll[Int]
    comptime Out = Poll[Int].Applied[Both[Park, Park]]
    def call_once(deinit self, var poll: Self.Arg) -> Self.Out:
        self.saved[] = Optional(poll.copy())
        return poll.apply(both(Park(self.calls.copy()), Park(self.calls.copy())))


@fieldwise_init
struct Inner(OnceUnary):
    comptime Arg = Poll[Int]
    comptime Out = Poll[Int].Applied[Sleep[Int]]
    def call_once(deinit self, var poll: Self.Arg) -> Self.Out:
        return poll.apply(Sleep[Int](50))


@fieldwise_init
struct Outer(OnceUnary):
    comptime Arg = Poll[Int]
    comptime Out = Masked[_ConstantMask[Poll[Int].Applied[Sleep[Int]]], Int]
    def call_once(deinit self, var poll: Self.Arg) -> Self.Out:
        return uncancelable(poll.apply(Sleep[Int](50)))


@fieldwise_init
struct Protected(OnceUnary):
    var calls: ArcPointer[Int]
    comptime Arg = Poll[Int]
    comptime Body = Poll[Int].Applied[Park]
    comptime Cleanup = Poll[Int].Applied[Sleep[Int]]
    comptime Out = Guarantee[Self.Body, _ProgramUse[Self.Cleanup, ExitCase[Int]]]
    def call_once(deinit self, var poll: Self.Arg) -> Self.Out:
        return guarantee(poll.apply(Park(self.calls.copy())), poll.apply(Sleep[Int](50)))


@fieldwise_init
struct FailFactory(OnceUnary):
    var token: CancellationToken
    comptime Arg = Poll[Int]
    comptime Out = Pure[Int, Int]
    comptime Error = Int
    def call_once(deinit self, var poll: Self.Arg) raises Int -> Self.Out:
        self.token.cancel()
        raise 19


def masked_timer[P: Machine](var program: P) where P.Error == Int:
    var clock = Clock.manual()
    var driver = Driver(program^, CancellationToken(), clock)
    check(driver.poll(100).deadline.value() == 50, "mask propagates manual clock")
    driver.cancel()
    check(driver.poll(100).polls == 0, "cancellation cannot unmask a parked timer")
    clock.advance_to(50)
    check(driver.poll(100).completed, "masked timer finishes normally")
    var outcome = driver^.finish()
    check(outcome.take().is_ok(), "terminal masked success survives the pending request")


def active_and_stale():
    var calls = ArcPointer(0)
    var saved = ArcPointer(Optional[Poll[Int]]())
    var driver = Driver(uncancelable_with[Int](Active(calls.copy(), saved.copy())))
    check(not driver.poll(100).runnable and calls[] == 2, "restored child pair parks")
    driver.cancel()
    check(driver.poll(100).completed and calls[] == 4, "active Poll restores cancellation to structured children")
    var runtime = driver.task.context._runtime.value().copy()
    check(not driver^.finish(), "restored cancellation retained")
    var guard = _lock_metadata(runtime._cell)
    check(guard.cell[].slot.value().active == 0, "restoration preserves current scheduler parent and retires subtree")
    _ = guard^
    masked_timer(uncancelable(saved[].value().apply(Sleep[Int](50))))
    var later = run(saved[].value().apply(pure[Int](42)))
    check(later.take()._take_ok() == 42, "escaped Poll does not restore its old canceled token")


def cleanup_region():
    var calls = ArcPointer(0)
    var clock = Clock.manual()
    var driver = Driver(uncancelable_with[Int](Protected(calls.copy())), CancellationToken(), clock)
    check(not driver.poll(100).runnable and calls[] == 1, "body is cancelable inside mask")
    driver.cancel()
    var cleanup = driver.poll(100)
    check(not cleanup.runnable and cleanup.deadline.value() == 50 and calls[] == 2, "same Poll cannot pierce finalizer's new region")
    driver.cancel()
    check(driver.poll(100).polls == 0, "repeated cancellation cannot repoll masked cleanup")
    var moved = driver^
    clock.advance_to(50)
    check(moved.poll(100).completed, "moved mask drains cleanup")
    check(not moved^.finish(), "cancellation preserved across cleanup")


def factory_errors():
    var token = CancellationToken()
    var outcome = run(uncancelable_with[Int](FailFactory(token.copy())), token)
    var failed = outcome.take()._take_err()
    check(failed.errors.first() == 19 and failed.canceled, "factory error and pending cancellation retained")


def main():
    masked_timer(uncancelable(Sleep[Int](50)))
    masked_timer(uncancelable_with[Int](Outer()))
    masked_timer(uncancelable(uncancelable_with[Int](Inner())))
    active_and_stale()
    cleanup_region()
    factory_errors()
    print("async masking: active and stale Poll, nested regions, child scheduling, timed cleanup, factory errors")
