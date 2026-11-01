"""A move-only loop state remains unique through yielding and failed steps."""
from std.memory import ArcPointer
from fp.callables import MutableUnary
from fp.data import ControlFlow, Continue, Break
from fp.effects import IOContext, CancellationToken
from state_machine import Machine, Step, Wait, Task, loop
from foundation import check, success, failure, Failure


@fieldwise_init
struct State(Movable):
    var n: Int
    var stats: ArcPointer[List[Int]]
    def __deinit__(deinit self):
        self.stats[][0] += 1


struct Iteration(Machine):
    var state: Optional[State]
    var stats: ArcPointer[List[Int]]
    var fail: Bool
    var entered: Bool
    comptime Value = ControlFlow[Int, State]
    comptime Error = Failure

    def __init__(out self, var state: State, fail: Bool):
        self.stats = state.stats.copy()
        self.state = Optional(state^)
        self.fail = fail
        self.entered = False
        self.stats[][2] += 1
        check(self.stats[][2] == 1, "at most one live loop step")

    def __deinit__(deinit self):
        self.stats[][2] -= 1

    def poll(mut self, context: IOContext[Failure]) -> Step[Self.Value, Failure]:
        self.stats[][5] += 1
        if context.canceled():
            self.stats[][6] += 1
            return .ready(None)
        if not self.entered:
            self.entered = True
            return .pending(Wait())
        if self.fail and self.state.value().n == 3:
            return failure[Self.Value](72, self.stats)
        if self.state.value().n == 10000:
            return success[Self.Value, Failure](Self.Value(Break(10000)))
        var state = self.state.take()
        state.n += 1
        return success[Self.Value, Failure](Self.Value(Continue(state^)))


@fieldwise_init
struct Factory(MutableUnary):
    var mode: Int
    comptime Arg = State
    comptime Out = Iteration
    comptime Error = Failure
    def call_mut(mut self, var value: State) raises Failure -> Iteration:
        value.stats[][1] += 1
        if self.mode == 1 and value.n == 3:
            raise Failure(71, value.stats.copy())
        return Iteration(value^, self.mode == 2)


def case_body(stats: ArcPointer[List[Int]], mode: Int):
    var task = Task(loop(State(0, stats.copy()), Factory(mode)), CancellationToken())
    if mode >= 3:
        check(task.tick(), "factory creates deferred step")
        if mode == 4:
            check(task.tick(), "step enters before cancellation")
        task.cancel()
    while not task.done():
        check(task.tick(), "yielding loop remains runnable")
    var outcome = task^.finish()
    check(stats[][0] == 1 and stats[][2] == 0, "state destroyed once and no retained active step")
    if mode == 0:
        check(outcome.take()._take_ok() == 10000 and stats[][1] == 10001, "no factory invocation after Break")
    elif mode < 3:
        var error = outcome.take()._take_err()
        check(error.errors.first().code == (71 if mode == 1 else 72), "exact factory/step errors")
        check(stats[][1] == 4, "failure prevents next iteration")
    else:
        check(not outcome and stats[][1] == 1, "cancel prevents next factory")
        check(stats[][6] == Int(mode == 4), "only entered step observes cancellation")


def main():
    for mode in range(5):
        var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
        case_body(stats, mode)
        check(stats[][4] == Int(mode == 1 or mode == 2), "move-only errors released exactly once")
    print("loop lifecycle: move-only state, bounded active storage, yielding, errors, cancellation")
