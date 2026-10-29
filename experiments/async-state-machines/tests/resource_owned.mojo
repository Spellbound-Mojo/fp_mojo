"""Owned resources and successful values stay live through suspending release."""
from std.memory import ArcPointer
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok
from fp.effects import IOContext, ExitCase, EffectFailure
from fp.effects._async.kernel import Step, Wait, run
from fp.effects._async.scopes import CleanupMachine
from fp.effects._async.composition import Pure, pure
from fp.effects._async.resources import resource_case
from foundation import check

@fieldwise_init
struct Owned[o: ImmOrigin](Movable):
    var span: Span[Int, Self.o]
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

@fieldwise_init
struct Body[o: ImmOrigin](BorrowOnceCallable):
    comptime Payload = Owned[Self.o]
    comptime Result = Pure[Owned[Self.o], Int]
    var drops: ArcPointer[Int]
    def invoke_once(deinit self, ref value: Self.Payload) -> Self.Result:
        # The span carries its independent external origin, not this fresh loan.
        return pure[Int](Owned(value.span, self.drops^))

@fieldwise_init
struct Release[o: ImmOrigin](CleanupMachine):
    comptime Input = Owned[Self.o]
    comptime Error = Int
    var resource_drops: ArcPointer[Int]
    var value_drops: ArcPointer[Int]
    var calls: ArcPointer[Int]
    var phase: Int
    def poll[p: ImmOrigin](mut self, ref[p] value: Self.Input, exit: ExitCase[Int], context: IOContext[Int]) -> Step[NoneType, Int]:
        check(self.resource_drops[] == 0 and self.value_drops[] == 0, "cleanup retains resource and body result")
        check(value.span[0] == 41 and exit.is_success(), "cleanup borrows the exact live resource")
        if self.phase == 0:
            self.phase = 1
            return .pending(Wait())
        self.calls[] += 1
        var unit: NoneType = None
        return .ready(Optional(Result[NoneType, EffectFailure[Int]](Ok(unit))))

def exercise[o: ImmOrigin](ref[o] values: List[Int]):
    var resources = ArcPointer(0)
    var results = ArcPointer(0)
    var calls = ArcPointer(0)
    var recipe = resource_case(pure[Int](Owned(Span(values), resources.copy())), Release[o](resources.copy(), results.copy(), calls.copy(), 0))
    var outcome = run(recipe^.use(Body[o](results.copy())))
    check(resources[] == 1 and results[] == 0 and calls[] == 1, "release precedes resource destruction and result transfer")
    var result = outcome.take()._take_ok()
    check(result.span[0] == 41, "the external result origin remains valid")
    _ = result^
    check(results[] == 1, "successful owned result is destroyed exactly once")
    var unopened = resource_case(pure[Int](Owned(Span(values), resources.copy())), Release[o](resources.copy(), results.copy(), calls.copy(), 0))
    _ = unopened^
    check(resources[] == 2 and calls[] == 1, "dropping an unopened recipe runs no release")

def main():
    var values: List[Int] = [41]
    exercise(values)
    print("resources ownership: move-only owners, external origins, retained success, suspended cleanup, unopened drop")
