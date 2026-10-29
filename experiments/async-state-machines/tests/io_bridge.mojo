"""Canonical async imports, native delay, and inherited synchronous IO execution."""
from std.memory import ArcPointer
from fp.callables import OnceThunk
from fp.effects import IO, IOContext, CancellationToken, Outcome, EffectFailure
from fp.effects.protocols import ReaderAction
from fp.effects._async.kernel import Driver, Clock, run
from fp.effects._async.io import delay, eval_io
from fp.effects._async.finalization import uncancelable
from fp.data import Result, Ok
from foundation import check, Resource


def answer() -> Int:
    return 42


def broken() raises Int -> Int:
    raise 19


@fieldwise_init
struct Owned(OnceThunk):
    var resource: Resource
    comptime Out = Resource
    def call_once(deinit self) -> Self.Out:
        return self.resource^


@fieldwise_init
struct Endpoint(ReaderAction):
    var calls: ArcPointer[Int]
    var masked: Bool
    comptime Family = IO[Int]
    comptime Env = IOContext[Int]
    comptime Value = Int
    comptime Out[o: ImmOrigin] = Outcome[Int, Int]

    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        self.calls[] += 1
        check(context._clock.now() == 123, "IO must inherit the driver clock")
        check(Bool(context._runtime) and Bool(context._parent), "IO must inherit scheduler ancestry")
        check(context._masked == self.masked, "IO must inherit masking")
        context.request_cancel()
        return Optional(Result[Int, EffectFailure[Int]](Ok(42)))


def inherited[masked: Bool]():
    var calls = ArcPointer(0)
    var token = CancellationToken()
    var program = eval_io(Endpoint(calls.copy(), masked))
    check(calls[] == 0, "constructing IO bridge must not call endpoint")
    comptime if masked:
        var driver = Driver(uncancelable(program^), token, Clock.manual(123))
        while not driver.poll(1).completed:
            pass
        var result = driver^.finish()
        check(result.take()._take_ok() == 42, "masked IO result must survive cancellation")
    else:
        var driver = Driver(program^, token, Clock.manual(123))
        while not driver.poll(1).completed:
            pass
        check(not driver^.finish(), "unmasked IO settles late cancellation")
    check(token.requested() and calls[] == 1, "IO must use current token and run once")


def main():
    var direct = run(delay[Int](answer))
    check(direct.take()._take_ok() == 42, "native nonraising delay")
    var failed = run(delay[Int](broken))
    var failure = failed.take()._take_err()
    check(not failure.canceled, "native error must retain its cancellation flag")
    check(failure^.into_errors().into_list()[0] == 19, "native exact error must be captured")
    var stats = ArcPointer(List[Int](length=5, fill=0))
    var owned = delay[Int](Owned(Resource(String("owned delay"), stats.copy())))
    check(stats[][3] == 0, "unopened delay retains its capture")
    var result = run(owned^)
    check(stats[][3] == 0, "successful delay transfers capture into outcome")
    _ = result.take()._take_ok()
    check(stats[][3] == 1, "owned delay value destroyed once")
    var token = CancellationToken()
    token.cancel()
    check(not run(delay[Int](Owned(Resource(String("skipped delay"), stats.copy()))), token), "canceled entry skips delay")
    check(stats[][3] == 2, "skipped capture destroyed once")
    inherited[False]()
    inherited[True]()
    print("io bridge: native callbacks, ownership, inherited clock, masking, token, scheduler")
