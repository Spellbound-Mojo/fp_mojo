"""IO constructors and combinators: delay, defer, native callbacks, attempt, races, timers, cancellation and registration."""
from std.memory import ArcPointer
from fp.callables import OnceThunk, OnceUnary
from fp.data import Left, Right, NonEmptyList
from fp.effects import IOContext, CancellationToken, Outcome, EffectFailure
from fp.effects import IO as SyncIO
from fp.effects.protocols import ReaderAction
from fp.data import Result, Ok
from fp.effects._async.time import Duration
from fp.effects._async.callbacks import Completion
from state_machine import IO, Machine, Step, Wait, Task, Poll, run
from foundation import check, success


@fieldwise_init
struct Count(OnceThunk):
    var calls: ArcPointer[Int]
    comptime Out = Int
    comptime Error = Int

    def call_once(deinit self) raises Int -> Int:
        self.calls[] += 1
        if self.calls[] > 1:
            raise self.calls[]
        return 10


@fieldwise_init
struct Work(Machine):
    var id: Int
    var remaining: Int
    comptime Value = Int
    comptime Error = Int

    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        if context.canceled():
            return .ready(None)
        if self.remaining > 0:
            self.remaining -= 1
            return .pending(Wait())
        return success[Int, Int](self.id)


@fieldwise_init
struct Withdraw(Machine):
    var calls: ArcPointer[Int]
    comptime Value = NoneType
    comptime Error = Int

    def poll(mut self, context: IOContext[Int]) -> Step[NoneType, Int]:
        self.calls[] += 1
        var unit: NoneType = None
        return success[NoneType, Int](unit)


@fieldwise_init
struct Ignore(OnceUnary):
    var body: IO[Int, Int]
    comptime Arg = Poll[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var poll: Poll[Int]) -> IO[Int, Int]:
        return self.body^


@fieldwise_init
struct Endpoint(ReaderAction):
    var calls: ArcPointer[Int]
    comptime Family = SyncIO[Int]
    comptime Env = IOContext[Int]
    comptime Value = Int
    comptime Out[o: ImmOrigin] = Outcome[Int, Int]

    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        self.calls[] += 1
        return Optional(Result[Int, EffectFailure[Int]](Ok(42)))


def ten() -> Int:
    return 10


def label() -> String:
    return "io"


def refuse() raises Int -> Int:
    raise 5


def built() -> IO[Int, Int]:
    return IO[Int, Int].pure(3)


def triple(var value: Int) -> Int:
    return value * 3


def describe(var value: Int) -> String:
    return String(value)


def checked(var value: Int) raises Int -> Int:
    if value > 100:
        raise value
    return value


def next(var value: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(value + 1)


def rescue(var failure: EffectFailure[Int]) -> IO[Int, Int]:
    return IO[Int, Int].pure(-failure^.into_errors().into_list()[0])


def immediate(var completion: Completion[Int, Int]):
    _ = completion.complete(success[Int, Int](42)._outcome())


def masked(var poll: Poll[Int]) -> IO[Int, Int]:
    return IO[Int, Int].pure(8)


def value(var io: IO[Int, Int]) -> Int:
    var outcome = run(io^)
    return outcome.take()._take_ok()


def error(var io: IO[Int, Int]) -> Int:
    var outcome = run(io^)
    return outcome.take()._take_err().into_errors().into_list()[0]


def drain(var task: Task[IO[Int, Int]]) -> Outcome[Int, Int]:
    while not task.done():
        _ = task.tick()
    return task^.finish()


def construction():
    var calls = ArcPointer(0)
    var delayed = IO[Int, Int].delay(Count(calls.copy()))
    check(calls[] == 0, "delay defers its function")
    check(value(delayed^) == 10 and calls[] == 1, "delay evaluates once when run")
    check(value(IO[Int, Int].delay(ten)) == 10, "a native register-passable delay")
    var text = run(IO[String, Int].delay(label))
    check(text.take()._take_ok() == "io", "a native movable delay")
    check(error(IO[Int, Int].delay(refuse)) == 5, "a raising native delay fails with its error")
    check(value(IO[Int, Int].defer(built)) == 3, "a native defer builds the IO when reached")
    var endpoint_calls = ArcPointer(0)
    var bridged = IO[Int, Int].eval_io(Endpoint(endpoint_calls.copy()))
    check(endpoint_calls[] == 0 and value(bridged^) == 42 and endpoint_calls[] == 1, "eval_io runs a synchronous program once when reached")


def native_callbacks():
    check(value(IO[Int, Int].pure(4).map(triple).flat_map(next)) == 13, "native map and flat_map")
    var text = run(IO[Int, Int].pure(4).map(describe))
    check(text.take()._take_ok() == "4", "a native map to a movable result")
    check(error(IO[Int, Int].pure(101).map(checked)) == 101, "a raising native map fails with its error")
    check(value(IO[Int, Int].raise_error(6).handle_error_with(rescue)) == -6, "a native handler recovers")
    check(value(IO[Int, Int].uncancelable(masked)) == 8, "a native uncancelable factory")
    var attempted = run(IO[Int, Int].raise_error(9).attempt())
    check(attempted.take()._take_ok()._take_err().into_errors().into_list()[0] == 9, "attempt materializes failure")
    var ok = run(IO[Int, Int].pure(2).attempt())
    check(ok.take()._take_ok()._take_ok() == 2, "attempt wraps success")


def concurrency() raises:
    var pair = run(IO[Int, Int].lift(Work(1, 3)).both(IO[String, Int].pure("b")))
    var values = pair.take()._take_ok()
    check(values[0] == 1 and values[1] == "b", "both returns both values")
    var raced = run(IO[Int, Int].lift(Work(1, 5)).race(IO[Int, Int].lift(Work(2, 1))))
    check(raced.take()._take_ok().unwrap[Right[Int]]().into_payload() == 2, "race selects the first outcome")
    var first = run(IO[Int, Int].lift(Work(1, 0)).race_first(IO[Int, Int].never()))
    check(first.take()._take_ok().unwrap[Left[Int]]().into_payload() == 1, "race_first cancels and drains the loser")
    check(value(IO[Int, Int].never().timeout_to(Duration.milliseconds(1), IO[Int, Int].pure(7))) == 7, "timeout_to runs the fallback")
    check(value(IO[Int, Int].lift(Work(4, 0)).timeout_after(Duration.seconds(5), IO[Int, Int].pure(7))) == 4, "timeout_after keeps a fast result")
    check(value(IO[NoneType, Int].sleep(Duration.milliseconds(1)).map(ten_after)) == 10, "sleep then continue")


def ten_after(var unit: NoneType) -> Int:
    return 10


def cooperation():
    var task = Task(IO[NoneType, Int].cede().map(ten_after), CancellationToken())
    _ = task.tick()
    check(not task.done(), "cede yields once")
    var ceded = drain(task^)
    check(ceded.take()._take_ok() == 10, "cede then continue")
    var waiting = Task(IO[Int, Int].never(), CancellationToken())
    _ = waiting.tick()
    waiting.cancel()
    check(not drain(waiting^), "never completes only by cancellation")
    var canceled = run(IO[NoneType, Int].canceled().map(ten_after))
    check(not canceled, "canceled requests cancellation of the running program")
    var protected = run(IO[Int, Int].uncancelable(Ignore(IO[NoneType, Int].canceled().map(ten_after))))
    check(protected.take()._take_ok() == 10, "a mask defers observing a self-cancellation")


def registration():
    check(value(IO[Int, Int].async_(immediate)) == 42, "async_ completes from registration")
    var withdrawals = ArcPointer(0)
    check(value(IO[Int, Int].`async`(immediate, IO[NoneType, Int].lift(Withdraw(withdrawals.copy())))) == 42, "async completes from registration")
    check(withdrawals[] == 1, "async runs the withdrawal once")


def main() raises:
    construction()
    native_callbacks()
    concurrency()
    cooperation()
    registration()
    print("io operations: delay, defer, eval_io, native callbacks, attempt, both, races, timeouts, sleep, cede, never, canceled, async")
