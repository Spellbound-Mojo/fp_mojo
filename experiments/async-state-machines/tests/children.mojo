"""Child observation order, wake unions, cancellation draining and resources."""
from std.memory import ArcPointer
from fp.effects import IOContext, CancellationToken, EffectFailure, ExitCase
from fp.data import Result, Ok, Err, NonEmptyList, ControlFlow, Continue, Break
from fp.callables import OnceUnary, MutableUnary
from state_machine import Machine, Step, Wait, Signal, Task, run
from foundation import check, success, Failure, Resource, both


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
    check(task.tick(), "both children enter in one tick")
    check(not task.tick(), "two independent signals park the group")
    if first == 0:
        a.notify()
    else:
        b.notify()
    check(task.tick(), "either signal wakes its child")
    # A completed child wakes the pair, which never repolls the parked
    # sibling: the poll counts below stay at two per child.
    _ = task.tick()
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
                wait._interruptible = False
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


def main():
    for left in range(4):
        for right in range(4):
            for first in range(2):
                var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
                var errors = matrix_case(stats, left, right, first)
                check(stats[][4] == errors, "each move-only error destroyed once")
    print("children: 32 outcome/order cases over fiber pairs")
