"""Deterministic callback/cancellation interleavings and owned cleanup."""
from std.atomic import Atomic
from std.memory import ArcPointer
from fp.callables import OnceUnary
from fp.effects import IOContext, CancellationToken, Outcome, EffectFailure
from fp.data import Result, Err, NonEmptyList
from state_machine import Completion, Machine, Step, Wait, Signal, Task, callback, run
from foundation import both
from foundation import check, success, Resource, Failure


def failed[T: Movable & Deinitable](code: Int) -> Outcome[T, Int]:
    return Optional(Result[T, EffectFailure[Int]](Err(EffectFailure(NonEmptyList(code), False))))


@fieldwise_init
struct Register(OnceUnary):
    var saved: ArcPointer[Optional[Completion[Int, Int]]]
    var counts: ArcPointer[List[Int]]
    var mode: Int
    var fail: Bool
    comptime Arg = Completion[Int, Int]
    comptime Out = NoneType
    comptime Error = Int
    def call_once(deinit self, var done: Self.Arg) raises Int -> NoneType:
        self.counts[][0] += 1
        self.saved[] = Optional(done.copy())
        if self.mode == 1:
            check(done.complete(success[Int, Int](42)._outcome()), "immediate success accepted")
        elif self.mode == 2:
            check(done.complete(failed[Int](11)), "immediate failure accepted")
        elif self.mode == 3:
            check(done.complete(None), "producer cancellation accepted")
        if self.fail:
            raise 22
        return None


@fieldwise_init
struct Withdraw(Machine):
    var counts: ArcPointer[List[Int]]
    var gate: Signal
    var fail: Bool
    comptime Value = NoneType
    comptime Error = Int
    def poll(mut self, context: IOContext[Int]) -> Step[NoneType, Int]:
        check(context._masked and not context.canceled(), "withdrawal must be masked")
        self.counts[][1] += 1
        if self.counts[][1] == 1:
            var wait = Wait.changed(self.gate, self.gate.revision())
            wait._interruptible = False
            return .pending(wait^)
        if self.fail:
            return .ready(failed[NoneType](33))
        var unit: NoneType = None
        return success[NoneType, Int](unit)


def matrix_case(mode: Int, registration_failure: Bool, cleanup_failure: Bool, cancel: Bool):
    var saved = ArcPointer(Optional[Completion[Int, Int]]())
    var counts = ArcPointer(List[Int]([0, 0]))
    var gate = Signal()
    var task = Task(callback(Register(saved.copy(), counts.copy(), mode, registration_failure),
                             Withdraw(counts.copy(), gate.copy(), cleanup_failure)), CancellationToken())
    _ = task.tick()
    check(counts[][0] == 1, "registration exactly once")
    if cancel:
        task.cancel()
    elif mode == 0 and not registration_failure:
        _ = task.tick()
        check(not task.tick(), "uncompleted callback parks")
        check(saved[].value().complete(success[Int, Int](42)._outcome()), "delayed completion accepted")
    while counts[][1] == 0:
        _ = task.tick()
    check(not saved[].value().complete(success[Int, Int](999)._outcome()), "duplicates rejected during cleanup")
    if cancel:
        task.cancel()
    check(not task.tick() and counts[][1] == 1, "masked cleanup stays parked after duplicate and cancellation")
    var moved = task^
    gate.notify()
    while not moved.done():
        _ = moved.tick()
    var outcome = moved^.finish()
    check(counts[][1] == 2, "cleanup resumes once")
    check(not saved[].value().complete(failed[Int](99)), "late callback safely rejected after owner finishes")
    var n = Int(mode == 2) + Int(registration_failure) + Int(cleanup_failure)
    if n:
        check(Bool(outcome) and outcome.value().is_err(), "errors retained")
        var error = outcome.take()._take_err()
        check(error.canceled == (cancel or mode == 3), "cancellation flag including registration failure")
        var errors = error^.into_errors().into_list()
        check(len(errors) == n, "all errors retained")
        var index = 0
        if mode == 2:
            check(errors[index] == 11, "callback error first")
            index += 1
        if registration_failure:
            check(errors[index] == 22, "registration error next")
            index += 1
        if cleanup_failure:
            check(errors[index] == 33, "cleanup error last")
    elif cancel or mode == 3:
        check(not outcome, "canceled outcome")
    else:
        check(outcome.take()._take_ok() == 42, "typed value retained")


@fieldwise_init
struct Producer(Machine):
    var saved: ArcPointer[Optional[Completion[Int, Int]]]
    var counts: ArcPointer[List[Int]]
    var gate: Signal
    comptime Value = Int
    comptime Error = Int
    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        if not self.saved[]:
            return .pending(Wait())
        _ = self.saved[].value().complete(success[Int, Int](42)._outcome())
        if self.counts[][1] == 0:
            return .pending(Wait())
        self.gate.notify()
        return success[Int, Int](7)


@fieldwise_init
struct Reenter(Movable):
    var done: Completion[Int, Int]
    var dropped: ArcPointer[Int]
    def __deinit__(deinit self):
        self.dropped[] += 1
        _ = self.done.complete(success[Int, Int](8)._outcome())


struct LockProbe(Movable):
    """Record whether the completion's lock is held when this payload is destroyed."""
    var lock: Pointer[Atomic[UInt8], MutUntrackedOrigin]
    var held: ArcPointer[Int]

    def __init__(out self, lock: Pointer[Atomic[UInt8], MutUntrackedOrigin], held: ArcPointer[Int]):
        self.lock = lock
        self.held = held.copy()

    def __deinit__(deinit self):
        self.held[] = Int(self.lock[].load())


def ownership():
    var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
    var done = Completion[Resource, Failure]()
    check(done.complete(success[Resource, Failure](Resource(String("owned"), stats.copy()))._outcome()), "move-only accepted")
    check(not done.complete(success[Resource, Failure](Resource(String("duplicate"), stats.copy()))._outcome()), "move-only duplicate rejected")
    check(stats[][3] == 1, "rejected value destroyed immediately")
    var selected = done._select(False)
    _ = selected^
    check(stats[][3] == 2, "accepted value destroyed once")
    var dropped = ArcPointer(0)
    var inner = Completion[Int, Int]()
    var outer = Completion[Reenter, Int]()
    _ = outer.complete(None)
    check(not outer.complete(success[Reenter, Int](Reenter(inner.copy(), dropped.copy()))._outcome()), "reentrant destructor rejected")
    var completed = inner._select(False)
    var outcome = completed.take()
    check(dropped[] == 1 and outcome.take()._take_ok() == 8, "destructors may complete another callback")
    var probed = Completion[LockProbe, Int]()
    var lock = Pointer(to=probed._cell[].lock).unsafe_origin_cast[MutUntrackedOrigin]()
    var held = ArcPointer(-1)
    _ = probed.complete(None)
    check(not probed.complete(success[LockProbe, Int](LockProbe(lock, held))._outcome()), "late payload rejected")
    check(held[] == 0, "rejected payloads are destroyed after the lock is released")


def main():
    for mode in range(4):
        for registration in range(2):
            for cleanup in range(2):
                for cancel in range(2):
                    matrix_case(mode, Bool(registration), Bool(cleanup), Bool(cancel))
    var saved = ArcPointer(Optional[Completion[Int, Int]]())
    var counts = ArcPointer(List[Int]([0, 0]))
    var gate = Signal()
    var token = CancellationToken()
    token.cancel()
    var skipped = run(callback(Register(saved.copy(), counts.copy(), 0, False), Withdraw(counts.copy(), gate.copy(), False)), token)
    check(not skipped and counts[][0] == 0 and counts[][1] == 0, "unopened registration and cleanup skipped")
    var result = run(both(callback(Register(saved.copy(), counts.copy(), 0, False), Withdraw(counts.copy(), gate.copy(), False)),
                          Producer(saved.copy(), counts.copy(), gate.copy())))
    var values = result.take()._take_ok()
    check(values[0] == 42 and values[1] == 7, "structured producer wakes registered callback")
    ownership()
    print("callbacks: 32 interleavings, immediate/delayed/late completion, cleanup, ownership, unlocked rejection, structured producer")
