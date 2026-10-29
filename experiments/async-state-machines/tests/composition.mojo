"""Ownership handoff, construction errors, iteration and cooperative progress."""
from std.memory import ArcPointer
from fp.callables import OnceUnary, MutableUnary
from fp.data import ControlFlow, Break, Continue
from fp.effects import IOContext, CancellationToken
from state_machine import Machine, Step, Wait, Task, Pure, pure, bind, loop, run, run_pair
from foundation import check, success, Resource, Failure


@fieldwise_init
struct Add(OnceUnary):
    comptime Arg = Int
    comptime Out = Pure[Int, Int]
    def call_once(deinit self, var value: Int) -> Self.Out:
        return pure[Int](value + 1)


@fieldwise_init
struct Transfer(OnceUnary):
    var calls: ArcPointer[Int]
    var fail: Bool
    comptime Arg = Resource
    comptime Out = Pure[Resource, Failure]
    comptime Error = Failure
    def call_once(deinit self, var value: Resource) raises Failure -> Self.Out:
        self.calls[] += 1
        check(value.text == "owned payload", "continuation receives owned String contents")
        if self.fail:
            raise Failure(71, value.stats.copy())
        return pure[Failure](value^)


def ownership_case(cancel: Bool, fail: Bool):
    var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
    var calls = ArcPointer(0)
    var task = Task(bind(pure[Failure](Resource(String("owned payload"), stats.copy())), Transfer(calls.copy(), fail)), CancellationToken())
    check(task.tick(), "source completes")
    check(calls[] == 0 and stats[][3] == 0, "handoff owns value before factory entry")
    if cancel:
        task.cancel()
    while not task.done():
        _ = task.tick()
    var outcome = task^.finish()
    if cancel:
        check(not outcome and calls[] == 0 and stats[][3] == 1, "cancel skips factory and destroys owned input once")
    elif fail:
        check(Bool(outcome) and outcome.value().is_err(), "construction error captured")
        var error = outcome.take()._take_err()
        check(error.errors.first().code == 71, "exact construction error")
        check(calls[] == 1 and stats[][3] == 1, "failed factory consumes input once")
    else:
        check(Bool(outcome) and outcome.value().is_ok(), "next machine succeeds")
        var value = outcome.take()._take_ok()
        check(value.text == "owned payload" and calls[] == 1, "ownership moved through both machines")


@fieldwise_init
struct Count(MutableUnary):
    var calls: ArcPointer[Int]
    var limit: Int
    comptime Arg = Int
    comptime Out = Pure[ControlFlow[Int, Int], Int]
    def call_mut(mut self, var value: Int) -> Self.Out:
        self.calls[] += 1
        if value == self.limit:
            return pure[Int](ControlFlow[Int, Int](Break(value)))
        return pure[Int](ControlFlow[Int, Int](Continue(value + 1)))


@fieldwise_init
struct Neighbor(Machine):
    var calls: ArcPointer[Int]
    var remaining: Int
    comptime Value = Int
    comptime Error = Int
    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        if self.remaining == 0:
            check(self.calls[] < 1000000, "loop yields to sibling before finishing")
            return success[Int, Int](self.calls[])
        self.remaining -= 1
        return .pending(Wait())


def main():
    ownership_case(False, False)
    ownership_case(False, True)
    ownership_case(True, False)
    var result = run(bind(bind(pure[Int](40), Add()), Add()))
    check(result.take()._take_ok() == 42, "typed sequencing")
    var calls = ArcPointer(0)
    var results = run_pair(loop(0, Count(calls.copy(), 1000000)), Neighbor(calls.copy(), 100), CancellationToken(), CancellationToken())
    check(results[0].take()._take_ok() == 1000000, "million iterations")
    check(results[1].take()._take_ok() > 0 and calls[] == 1000001, "no invocation after Break")
    print("composition: ownership, factory errors, cancellation, million iterations, fairness")
