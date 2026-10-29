"""Nested scopes preserve acquisition, cancellation, cleanup order and all errors."""
from std.memory import ArcPointer
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok, Err, NonEmptyList
from fp.effects import IOContext, ExitCase, EffectFailure
from fp.effects._async.kernel import Machine, Step, Wait, Driver, Clock
from fp.effects import CancellationToken
from fp.effects._async.scopes import CleanupMachine, ScopedMachine
from fp.effects._async.composition import Pure, pure
from fp.effects._async.resources import resource_case, ResourceCase
from foundation import check

@fieldwise_init
struct Acquire(Machine):
    comptime Value = Int
    comptime Error = Int
    var value: Int
    var fail: Bool
    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        if self.fail:
            return .ready(Optional(Result[Int, EffectFailure[Int]](Err(EffectFailure(NonEmptyList(90), False)))))
        return .ready(Optional(Result[Int, EffectFailure[Int]](Ok(self.value))))

@fieldwise_init
struct Release(CleanupMachine):
    comptime Input = Int
    comptime Error = Int
    var log: ArcPointer[List[Int]]
    var fail: Bool
    var phase: Int
    def poll[o: ImmOrigin](mut self, ref[o] value: Int, exit: ExitCase[Int], context: IOContext[Int]) -> Step[NoneType, Int]:
        check(not context.canceled(), "cleanup must be masked")
        if self.phase == 0:
            self.phase = 1
            return .pending(Wait())
        self.log[].append(value)
        if value == 10:
            if exit.is_error():
                check(exit.failure().value().errors.first() == 90, "outer cleanup sees the original failure first")
            else:
                check(exit.is_canceled(), "cancellation can skip body entry")
        if self.fail:
            return .ready(Optional(Result[NoneType, EffectFailure[Int]](Err(EffectFailure(NonEmptyList(value), False)))))
        var unit: NoneType = None
        return .ready(Optional(Result[NoneType, EffectFailure[Int]](Ok(unit))))

comptime Resource = ResourceCase[Acquire, Release]

@fieldwise_init
struct Next(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Resource
    var log: ArcPointer[List[Int]]
    var mode: Int
    comptime Failure = Int
    def invoke_once(deinit self, ref value: Int) raises Int -> Resource:
        if self.mode == 1:
            raise 90
        return resource_case(Acquire(value + 10, self.mode == 2), Release(self.log^, True, 0))

@fieldwise_init
struct Body(ScopedMachine):
    comptime Input = Int
    comptime Value = Int
    comptime Error = Int
    var phase: Int
    def poll[o: ImmOrigin](mut self, ref[o] value: Int, context: IOContext[Int]) -> Step[Int, Int]:
        if self.phase == 0:
            self.phase = 1
            return .pending(Wait())
        check(value == 20, "body borrows the dependent resource")
        context.request_cancel()
        return .ready(Optional(Result[Int, EffectFailure[Int]](Err(EffectFailure(NonEmptyList(90), False)))))

def main():
    for mode in range(4):
        var log = ArcPointer(List[Int]())
        var recipe = resource_case(Acquire(10, False), Release(log.copy(), True, 0)).flat_map(Next(log.copy(), mode))
        var driver = Driver(recipe^.use(Body(0)), CancellationToken(), Clock.manual(0))
        check(not driver.poll(1).completed, "successful acquisition yields before body entry")
        if mode == 3:
            driver.cancel()
        while not driver.poll(1).completed:
            pass
        var outcome = driver^.finish()
        var failure = outcome.take()._take_err()
        check(failure.canceled == (mode == 0 or mode == 3), "cancellation remains independent of errors")
        var errors = failure^.into_errors().into_list()
        if mode == 0:
            check(len(errors) == 3 and errors[0] == 90 and errors[1] == 20 and errors[2] == 10, "body, inner, outer failure order")
            check(len(log[]) == 2 and log[][0] == 20 and log[][1] == 10, "suspended cleanup runs inner before outer")
        else:
            check(len(log[]) == 1 and log[][0] == 10, "unacquired inner resource executes no release")
            if mode == 3:
                check(len(errors) == 1 and errors[0] == 10, "cancellation before body still runs outer cleanup")
            else:
                check(len(errors) == 2 and errors[0] == 90 and errors[1] == 10, "factory or inner acquisition failure retains outer cleanup")
    print("resources: factory/acquisition/body failures, cancellation checkpoint, suspended masked release, ordered errors")
