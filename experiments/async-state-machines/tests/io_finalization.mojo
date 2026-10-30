"""IO finalizers and masks: exact exits, ordering, masked cleanup, and regions."""
from std.memory import ArcPointer
from fp.callables import OnceUnary, BorrowOnceCallable
from fp.effects import IOContext, CancellationToken, Outcome, EffectFailure, ExitCase
from state_machine import IO, Machine, Step, Wait, Task, Poll, run
from foundation import check, success, Failure

# Stats slots: 0 cleanup polls, 1 cleanups that observed cancellation,
# 2 leaves destroyed, 3 continuations dropped unopened, 4 failures destroyed.
comptime CLEANUP_POLLS = 0
comptime CLEANUP_SAW_CANCEL = 1
comptime LEAVES = 2
comptime DROPPED = 3
comptime FAILURES = 4


def new_stats() -> ArcPointer[List[Int]]:
    return ArcPointer(List[Int]([0, 0, 0, 0, 0]))


def new_log() -> ArcPointer[List[Int]]:
    return ArcPointer(List[Int]())


@fieldwise_init
struct Work(Machine):
    """A body leaf that yields, observes cancellation, and logs its id on success."""
    var id: Int
    var remaining: Int
    var log: ArcPointer[List[Int]]
    comptime Value = Int
    comptime Error = Failure

    def poll(mut self, context: IOContext[Failure]) -> Step[Int, Failure]:
        if context.canceled():
            return .ready(None)
        if self.remaining > 0:
            self.remaining -= 1
            return .pending(Wait())
        self.log[].append(self.id)
        return success[Int, Failure](self.id)


@fieldwise_init
struct Cleanup(Machine):
    """A cleanup leaf that yields, records whether it saw cancellation, and logs its tag."""
    var tag: Int
    var remaining: Int
    var log: ArcPointer[List[Int]]
    var stats: ArcPointer[List[Int]]
    comptime Value = NoneType
    comptime Error = Failure

    def __deinit__(deinit self):
        self.stats[][LEAVES] += 1

    def poll(mut self, context: IOContext[Failure]) -> Step[NoneType, Failure]:
        self.stats[][CLEANUP_POLLS] += 1
        if context.canceled():
            self.stats[][CLEANUP_SAW_CANCEL] += 1
        if self.remaining > 0:
            self.remaining -= 1
            return .pending(Wait())
        self.log[].append(self.tag)
        var unit: NoneType = None
        return success[NoneType, Failure](unit)


def cleanup(tag: Int, remaining: Int, log: ArcPointer[List[Int]], stats: ArcPointer[List[Int]]) -> IO[NoneType, Failure]:
    return IO[NoneType, Failure].lift(Cleanup(tag, remaining, log.copy(), stats.copy()))


@fieldwise_init
struct Record(BorrowOnceCallable):
    """Log the exact exit: 100 success, 200 plus the first error code, 300 cancellation."""
    var log: ArcPointer[List[Int]]
    comptime Payload = ExitCase[Failure]
    comptime Result = IO[NoneType, Failure]

    def invoke_once(deinit self, ref exit: ExitCase[Failure]) -> IO[NoneType, Failure]:
        if exit.is_success():
            self.log[].append(100)
        elif exit.is_error():
            self.log[].append(200 + exit.failure().value().errors.first().code)
        else:
            self.log[].append(300)
        var unit: NoneType = None
        return IO[NoneType, Failure].pure(unit)


@fieldwise_init
struct Region(OnceUnary):
    """Run the body masked, or through the region's Poll when restoring."""
    var body: IO[Int, Failure]
    var restore: Bool
    comptime Arg = Poll[Failure]
    comptime Out = IO[Int, Failure]

    def call_once(deinit self, var poll: Poll[Failure]) -> IO[Int, Failure]:
        if self.restore:
            return self.body^.restore(poll)
        return self.body^


@fieldwise_init
struct Next(OnceUnary):
    var stats: ArcPointer[List[Int]]
    comptime Arg = Int
    comptime Out = IO[Int, Failure]

    def __deinit__(deinit self):
        self.stats[][DROPPED] += 1

    def call_once(deinit self, var value: Int) -> IO[Int, Failure]:
        return IO[Int, Failure].pure(value + 1)


@fieldwise_init
struct CancelThenRegion(OnceUnary):
    """Request cancellation, then return a region whose entry must observe it."""
    var token: CancellationToken
    var stats: ArcPointer[List[Int]]
    comptime Arg = Int
    comptime Out = IO[Int, Failure]

    def call_once(deinit self, var value: Int) -> IO[Int, Failure]:
        self.token.cancel()
        return IO[Int, Failure].uncancelable(Region(IO[Int, Failure].pure(value), False))


def drain(var task: Task[IO[Int, Failure]]) -> Outcome[Int, Failure]:
    while not task.done():
        _ = task.tick()
    return task^.finish()


def errors(var outcome: Outcome[Int, Failure]) -> List[Int]:
    var codes = List[Int]()
    var failure = outcome.take()._take_err()
    var list = failure^.into_errors().into_list()
    for index in range(len(list)):
        codes.append(list[index].code)
    return codes^


def ordering_and_errors():
    var log = new_log()
    var stats = new_stats()
    var ok = IO[Int, Failure].lift(Work(5, 2, log.copy())).guarantee(cleanup(10, 1, log, stats))
    var value = run(ok^)
    check(value.take()._take_ok() == 5 and log[] == List[Int]([5, 10]), "cleanup runs after a successful body")
    var failed = IO[Int, Failure].raise_error(Failure(7, stats.copy())).guarantee(cleanup(11, 0, log, stats))
    check(errors(run(failed^)) == List[Int]([7]) and log[][2] == 11, "cleanup runs after failure")
    var both = IO[Int, Failure].raise_error(Failure(7, stats.copy())).guarantee(IO[NoneType, Failure].raise_error(Failure(8, stats.copy())))
    check(errors(run(both^)) == List[Int]([7, 8]), "body errors precede cleanup errors")
    var nested = IO[Int, Failure].raise_error(Failure(7, stats.copy())).guarantee(cleanup(1, 0, log, stats)).guarantee(cleanup(2, 0, log, stats))
    check(errors(run(nested^)) == List[Int]([7]) and log[][3] == 1 and log[][4] == 2, "inner cleanup runs first")
    check(stats[][FAILURES] == 4, "every failure destroyed once")


def exact_exits():
    var log = new_log()
    var stats = new_stats()
    _ = run(IO[Int, Failure].pure(1).guarantee_case(Record(log.copy())))
    _ = run(IO[Int, Failure].raise_error(Failure(4, stats.copy())).guarantee_case(Record(log.copy())))
    var task = Task(IO[Int, Failure].lift(Work(9, 100, log.copy())).guarantee_case(Record(log.copy())), CancellationToken())
    _ = task.tick()
    task.cancel()
    var outcome = drain(task^)
    check(not outcome, "canceled body settles as cancellation")
    check(log[] == List[Int]([100, 204, 300]), "the case factory borrows each exact exit")


def cancel_only():
    var log = new_log()
    var stats = new_stats()
    var ok = IO[Int, Failure].pure(3).on_cancel(cleanup(20, 0, log, stats))
    var value = run(ok^)
    check(value.take()._take_ok() == 3, "success skips on_cancel")
    check(len(log[]) == 0 and stats[][CLEANUP_POLLS] == 0 and stats[][LEAVES] == 1, "skipped cleanup destroyed unopened")
    var task = Task(IO[Int, Failure].lift(Work(9, 100, log.copy())).on_cancel(cleanup(21, 0, log, stats)), CancellationToken())
    _ = task.tick()
    task.cancel()
    check(not drain(task^) and log[] == List[Int]([21]), "on_cancel runs on cancellation")


def masked_cleanup():
    var log = new_log()
    var stats = new_stats()
    var task = Task(IO[Int, Failure].lift(Work(9, 100, log.copy())).guarantee(cleanup(30, 3, log, stats)), CancellationToken())
    _ = task.tick()
    task.cancel()
    check(not drain(task^), "canceled body with cleanup settles as cancellation")
    check(stats[][CLEANUP_POLLS] == 4 and stats[][CLEANUP_SAW_CANCEL] == 0, "cleanup suspends masked to completion")
    check(log[] == List[Int]([30]), "cleanup finished once")


def masked_regions():
    var log = new_log()
    var stats = new_stats()
    var protected = Task(IO[Int, Failure].uncancelable(Region(IO[Int, Failure].lift(Work(9, 3, log.copy())), False)), CancellationToken())
    _ = protected.tick()
    protected.cancel()
    var survived = drain(protected^)
    check(survived.take()._take_ok() == 9, "a masked success survives cancellation")
    var checkpoint = Task(IO[Int, Failure].uncancelable(Region(IO[Int, Failure].lift(Work(9, 3, log.copy())), False)).flat_map(Next(stats.copy())), CancellationToken())
    _ = checkpoint.tick()
    checkpoint.cancel()
    check(not drain(checkpoint^) and stats[][DROPPED] == 1, "the next checkpoint observes cancellation")
    var restored = Task(IO[Int, Failure].uncancelable(Region(IO[Int, Failure].lift(Work(8, 100, log.copy())), True)), CancellationToken())
    _ = restored.tick()
    restored.cancel()
    check(not drain(restored^), "poll restores cancellation inside the region")
    check(log[] == List[Int]([9, 9]), "only masked bodies completed")


def region_entry():
    var stats = new_stats()
    var token = CancellationToken()
    var task = Task(IO[Int, Failure].pure(1).flat_map(CancelThenRegion(token.copy(), stats.copy())), token)
    check(not drain(task^), "a region entered after cancellation does not start")


def main():
    ordering_and_errors()
    exact_exits()
    cancel_only()
    masked_cleanup()
    masked_regions()
    region_entry()
    print("io finalization: ordered cleanup, merged errors, exact exits, cancel-only cleanup, masked cleanup and regions")
