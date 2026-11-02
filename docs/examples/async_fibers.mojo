"""Start, join and cancel fibers; combine them with both, race and a supervisor."""
from fp.callables import OnceUnary
from fp.data import Left
from fp.effects import Outcome
from fp.effects.async_runtime import IO, Deferred, Duration, Fiber, RaceResult, Supervisor, run


def value[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    """The program's success value; a failure or cancellation aborts."""
    var success = outcome.take().to_optional()
    return success.take()


def times_seven(value: Int) -> Int:
    return value * 7


@fieldwise_init
struct TakeValue(OnceUnary):
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Int:
        return value(outcome^)


@fieldwise_init
struct Join(OnceUnary):
    """Join a fiber and produce its value."""
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join().map(TakeValue())


# ===--- cancel a running child ---=== #


def note_cleanup():
    print("child cleanup ran")


@fieldwise_init
struct WaitForever(OnceUnary):
    comptime Arg = Bool
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var completed: Bool) -> IO[NoneType, Int]:
        return IO[NoneType, Int].never()


@fieldwise_init
struct WasCanceled(OnceUnary):
    comptime Arg = Outcome[NoneType, Int]
    comptime Out = Bool

    def call_once(deinit self, var outcome: Outcome[NoneType, Int]) -> Bool:
        return not outcome


@fieldwise_init
struct JoinAfterCancel(OnceUnary):
    var fiber: Fiber[NoneType, Int]
    comptime Arg = NoneType
    comptime Out = IO[Bool, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Bool, Int]:
        return self.fiber^.join().map(WasCanceled())


@fieldwise_init
struct CancelOnceStarted(OnceUnary):
    """Wait until the child has entered its guarded region, then cancel it."""
    var started: Deferred[Int]
    comptime Arg = Fiber[NoneType, Int]
    comptime Out = IO[Bool, Int]

    def call_once(deinit self, var fiber: Fiber[NoneType, Int]) -> IO[Bool, Int]:
        var cancel = fiber.cancel()
        return self.started.get[Int]().flat_map(Then(cancel^)).flat_map(JoinAfterCancel(fiber^))


@fieldwise_init
struct Then(OnceUnary):
    var next: IO[NoneType, Int]
    comptime Arg = Int
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var ignored: Int) -> IO[NoneType, Int]:
        return self.next^


def cancel_running() -> IO[Bool, Int]:
    var started = Deferred[Int]()
    var child = started.complete[Int](1).flat_map(WaitForever()).guarantee(IO[NoneType, Int].delay(note_cleanup))
    return child^.start().flat_map(CancelOnceStarted(started^))


# ===--- both, race and a supervisor ---=== #


def add_pair(var pair: Tuple[Int, Int]) -> Int:
    return pair[0] + pair[1]


def left_won(var result: RaceResult[Int, Int]) -> Bool:
    return result.isa[Left[Int]]()


def one(var unit: NoneType) -> Int:
    return 1


@fieldwise_init
struct SuperviseAndJoin(OnceUnary):
    """Supervise a child, then join it before the supervisor is released."""
    comptime Arg = Supervisor[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var supervisor: Supervisor[Int]) -> IO[Int, Int]:
        return supervisor.supervise(IO[Int, Int].pure(6).map(times_seven)).flat_map(Join())


def main() raises:
    # A fiber runs beside its owner; joining it produces its outcome.
    var joined = run(IO[Int, Int].pure(6).map(times_seven).start().flat_map(Join()))
    print("joined:", value(joined^))

    # Canceling a child that has started runs its finalizers, then joins as canceled.
    var canceled = run(cancel_running())
    print("canceled:", value(canceled^))

    # both runs two fibers and keeps both values.
    var both = run(IO[Int, Int].pure(20).both(IO[Int, Int].pure(22)).map(add_pair))
    print("both:", value(both^))

    # race keeps the first to finish and cancels the other.
    var sleeper = IO[NoneType, Int].sleep(Duration.milliseconds(1)).map(one)
    var raced = run(sleeper^.race(IO[Int, Int].never()).map(left_won))
    print("left won the race:", value(raced^))

    # A supervisor owns fibers beyond the program that started them.
    var supervised = run(Supervisor[Int].scoped(SuperviseAndJoin()))
    print("supervised:", value(supervised^))
