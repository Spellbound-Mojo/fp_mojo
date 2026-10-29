"""Child observation order, wake unions, cancellation draining and resources."""
from std.memory import ArcPointer
from fp.effects import IOContext, CancellationToken, EffectFailure, ExitCase
from fp.data import Result, Ok, Err, NonEmptyList, ControlFlow, Continue, Break
from fp.callables import OnceUnary, MutableUnary
from state_machine import Machine, ScopedMachine, CleanupMachine, Scope, Step, Wait, Signal, Task, Pure, pure, bind, loop, both, scoped_both, run
from foundation import check, success, Failure, Resource


@fieldwise_init
struct Terminal(Machine):
    var signal: Signal
    var stats: ArcPointer[List[Int]]
    var id: Int
    var mode: Int
    var entered: Bool
    comptime Value = Int
    comptime Error = Failure
    def poll(mut self, context: IOContext[Failure]) -> Step[Int, Failure]:
        self.stats[][self.id] += 1
        if not self.entered:
            self.entered = True
            return .pending(Wait.changed(self.signal, self.signal.revision()))
        if self.mode == 1 or self.mode == 3:
            return .ready(Optional(Result[Int, EffectFailure[Failure]](Err(EffectFailure(
                NonEmptyList(Failure(11 + self.id, self.stats.copy())), self.mode == 3)))))
        if self.mode == 2:
            return .ready(None)
        return success[Int, Failure](self.id)


def matrix_case(stats: ArcPointer[List[Int]], left: Int, right: Int, first: Int) -> Int:
    var a = Signal()
    var b = Signal()
    var task = Task(both(Terminal(a.copy(), stats.copy(), 0, left, False), Terminal(b.copy(), stats.copy(), 1, right, False)), CancellationToken())
    check(task.tick() and task.tick(), "both children entered")
    check(not task.tick(), "two independent signals park the group")
    if first == 0:
        a.notify()
    else:
        b.notify()
    check(task.tick(), "either signal wakes its child")
    if (left if first == 0 else right) == 0:
        check(not task.tick(), "completed success does not repoll the parked sibling")
    a.notify()
    b.notify()
    while not task.done():
        check(task.tick(), "remaining child is ready")
    var outcome = task^.finish()
    check(stats[][0] == 2 and stats[][1] == 2, "no child polled after completion")
    var errors = Int(left == 1 or left == 3) + Int(right == 1 or right == 3)
    var canceled = left >= 2 or right >= 2 or (left if first == 0 else right) != 0
    if errors:
        var failure = outcome.take()._take_err()
        check(failure.canceled == canceled, "child cancellation policy independent of errors")
        var values = failure^.into_errors().into_list()
        check(len(values) == errors, "all child failures retained")
        check(values[0].code == (11 if left == 1 or left == 3 else 12), "declaration order independent of observation")
        if errors == 2:
            check(values[1].code == 12, "right failure follows left")
    elif canceled:
        check(not outcome, "canceled group cannot succeed")
    else:
        var values = outcome.take()._take_ok()
        check(values[0] == 0 and values[1] == 1, "success tuple order")
    return errors


@fieldwise_init
struct Controlled(Machine):
    var body: Signal
    var cleanup: Signal
    var stats: ArcPointer[List[Int]]
    var id: Int
    var fail: Bool
    var phase: Int
    comptime Value = Int
    comptime Error = Failure
    def poll(mut self, context: IOContext[Failure]) -> Step[Int, Failure]:
        self.stats[][self.id] += 1
        match self.phase:
            case 0:
                self.phase = 1
                return .pending(Wait.changed(self.body, self.body.revision()))
            case 1:
                check(context.canceled(), "parent cancellation delivered to entered child")
                self.phase = 2
                var wait = Wait.changed(self.cleanup, self.cleanup.revision())
                wait.interruptible = False
                return .pending(wait^)
            case 2:
                self.phase = 3
                if self.fail:
                    return .ready(Optional(Result[Int, EffectFailure[Failure]](Err(EffectFailure(
                        NonEmptyList(Failure(40 + self.id, self.stats.copy())), False)))))
                return .ready(None)
            case _:
                check(False, "child polled after completion")
                return .ready(None)


@fieldwise_init
struct Count(MutableUnary):
    comptime Arg = Int
    comptime Out = Pure[ControlFlow[Int, Int], Failure]
    def call_mut(mut self, var value: Int) -> Self.Out:
        if value == 100:
            return pure[Failure](ControlFlow[Int, Int](Break(value)))
        return pure[Failure](ControlFlow[Int, Int](Continue(value + 1)))


@fieldwise_init
struct Start(OnceUnary):
    var child: Controlled
    comptime Arg = Int
    comptime Out = Controlled
    def call_once(deinit self, var value: Int) -> Self.Out:
        check(value == 100, "loop completes before child body")
        return self.child^


@fieldwise_init
struct ScopedPipeline[P: Machine](ScopedMachine):
    var program: Self.P
    comptime Input = Resource
    comptime Value = Self.P.Value
    comptime Error = Self.P.Error
    def poll[o: ImmOrigin](mut self, ref[o] value: Resource, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        check(value.text == "nested resource" and value.stats[][3] == 0, "fresh resource borrow remains valid")
        return self.program.poll(context)


@fieldwise_init
struct Acquire(Machine):
    var stats: ArcPointer[List[Int]]
    comptime Value = Resource
    comptime Error = Failure
    def poll(mut self, context: IOContext[Failure]) -> Step[Resource, Failure]:
        check(context._masked, "acquire masked")
        return success[Resource, Failure](Resource(String("nested resource"), self.stats.copy()))


@fieldwise_init
struct Release(CleanupMachine):
    var stats: ArcPointer[List[Int]]
    var phase: Int
    comptime Input = Resource
    comptime Error = Failure
    def poll[o: ImmOrigin](mut self, ref[o] value: Resource, exit: ExitCase[Failure], context: IOContext[Failure]) -> Step[NoneType, Failure]:
        check(context._masked and exit.is_canceled(), "outer cleanup observes canceled group")
        check(value.text == "nested resource" and self.stats[][3] == 0, "outer owner alive in cleanup")
        check(self.stats[][0] == 3 and self.stats[][1] == 3 and self.stats[][2] == 3, "all descendants drained before release")
        self.stats[][5] += 1
        if self.phase == 0:
            self.phase = 1
            return .pending(Wait())
        var unit: NoneType = None
        return success[NoneType, Failure](unit)


def nested_scope():
    var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
    var body = Signal()
    var a = Signal()
    var b = Signal()
    var c = Signal()
    var left = ScopedPipeline(bind(loop(0, Count()), Start(Controlled(body.copy(), a.copy(), stats.copy(), 0, True, 0))))
    var mid = ScopedPipeline(bind(loop(0, Count()), Start(Controlled(body.copy(), b.copy(), stats.copy(), 1, False, 0))))
    var right = ScopedPipeline(bind(loop(0, Count()), Start(Controlled(body.copy(), c.copy(), stats.copy(), 2, True, 0))))
    var task = Task(Scope(Acquire(stats.copy()), scoped_both(left^, scoped_both(mid^, right^)), Release(stats.copy(), 0)), CancellationToken())
    var budget = 2000
    while stats[][0] + stats[][1] + stats[][2] < 3:
        check(budget > 0 and task.tick(), "nested loops and bind make progress")
        budget -= 1
    check(not task.tick(), "all descendants parked")
    task.cancel()
    while stats[][0] + stats[][1] + stats[][2] < 6:
        check(task.tick(), "cancellation propagates through nested group")
    check(not task.tick() and stats[][5] == 0, "masked children park without releasing resource")
    task.cancel()
    check(not task.tick(), "repeated parent cancellation cannot spin during cleanup")
    var moved = task^
    c.notify()
    check(moved.tick() and not moved.done(), "one descendant cleanup can finish first")
    check(not moved.tick() and stats[][3] == 0, "remaining cleanup still parks")
    a.notify()
    b.notify()
    while not moved.done():
        check(moved.tick(), "ready cleanup drains")
    var outcome = moved^.finish()
    var failed = outcome.take()._take_err()
    check(failed.canceled, "child errors retain parent cancellation")
    var errors = failed^.into_errors().into_list()
    check(len(errors) == 2 and errors[0].code == 40 and errors[1].code == 42, "nested errors follow declaration order")
    check(stats[][3] == 1 and stats[][5] == 2, "outer cleanup suspends and resource destroyed once")


def main():
    for left in range(4):
        for right in range(4):
            for first in range(2):
                var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
                var errors = matrix_case(stats, left, right, first)
                check(stats[][4] == errors, "each move-only error destroyed once")
    nested_scope()
    print("children: 32 outcome/order cases; nested loops, sequencing, scoped cancellation and masked cleanup")
