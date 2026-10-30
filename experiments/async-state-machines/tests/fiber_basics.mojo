"""Fibers: independent progress, parking joins, cancellation, join_with and nesting."""
from std.memory import ArcPointer
from std.os import abort
from fp.callables import OnceUnary
from fp.effects import CancellationToken, Outcome, EffectFailure
from fp.effects.async_runtime import IO, Fiber, Driver, Clock, Deferred, IORuntimeConfig, run


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def value_of(var outcome: Outcome[Int, Int]) -> Int:
    """A success's value, -1 for a failure's first error negated, -2 for cancellation."""
    if not outcome:
        return -2
    var result = outcome.take()
    if result.is_ok():
        return result^._take_ok()
    return -1000 - result^._take_err().errors.first()


@fieldwise_init
struct Count(OnceUnary):
    """Tail recursion through binds; counts its steps and samples another counter halfway."""
    var limit: Int
    var steps: ArcPointer[Int]
    var other: ArcPointer[Int]
    var seen: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var value: Int) -> IO[Int, Int]:
        self.steps[] += 1
        if value == self.limit // 2:
            self.seen[] = self.other[]
        if value == self.limit:
            return IO[Int, Int].pure(value)
        return IO[Int, Int].pure(value + 1).flat_map(Self(self.limit, self.steps^, self.other^, self.seen^))


def counting(limit: Int, steps: ArcPointer[Int], other: ArcPointer[Int], seen: ArcPointer[Int]) -> IO[Int, Int]:
    return IO[Int, Int].pure(0).flat_map(Count(limit, steps.copy(), other.copy(), seen.copy()))


@fieldwise_init
struct RunThenJoin(OnceUnary):
    """Run the owner's own work beside a started child, then join the child."""
    var work: IO[Int, Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return self.work^.flat_map(JoinAdd(fiber^))


@fieldwise_init
struct JoinAdd(OnceUnary):
    var fiber: Fiber[Int, Int]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var mine: Int) -> IO[Int, Int]:
        return self.fiber^.join().map(Add(mine))


@fieldwise_init
struct Add(OnceUnary):
    var base: Int
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Int:
        return self.base + value_of(outcome^)


def independent() raises:
    var main_steps = ArcPointer(0)
    var child_steps = ArcPointer(0)
    var seen = ArcPointer(-1)
    var unused = ArcPointer(-1)
    var child = counting(1_000, child_steps, main_steps, unused)
    var program = child^.start().flat_map(RunThenJoin(counting(1_000, main_steps, child_steps, seen)))
    var result = run(program^, IORuntimeConfig(1, 16))
    check(value_of(result^) == 2_000, "the owner joins its child's value")
    check(main_steps[] == 1_001 and child_steps[] == 1_001, "both programs ran to completion")
    check(seen[] > 0 and seen[] < 1_001, "the child progressed while the owner ran")


@fieldwise_init
struct StartCompleter(OnceUnary):
    """With the reader started, start a writer, then join the reader."""
    var cell: Deferred[Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Outcome[Int, Int], Int]

    def call_once(deinit self, var reader: Fiber[Int, Int]) -> IO[Outcome[Int, Int], Int]:
        var writer = IO[NoneType, Int].cede().flat_map(Complete(self.cell.copy()))
        return writer^.start().flat_map(JoinFirst(reader^))


@fieldwise_init
struct Complete(OnceUnary):
    var cell: Deferred[Int]
    comptime Arg = NoneType
    comptime Out = IO[Bool, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Bool, Int]:
        return self.cell.complete[Int](7)


@fieldwise_init
struct JoinFirst(OnceUnary):
    var first: Fiber[Int, Int]
    comptime Arg = Fiber[Bool, Int]
    comptime Out = IO[Outcome[Int, Int], Int]

    def call_once(deinit self, var second: Fiber[Bool, Int]) -> IO[Outcome[Int, Int], Int]:
        # The writer's handle is dropped; its owner drains it.
        return self.first^.join()


def parking_join() raises:
    var cell = Deferred[Int]()
    var program = cell.get[Int]().start().flat_map(StartCompleter(cell.copy()))
    var driver = Driver(program^, CancellationToken(), Clock(), IORuntimeConfig())
    var polls = 0
    while True:
        var progress = driver.poll()
        polls += 1
        if progress.completed:
            break
        check(polls < 1_000, "a parked join resumes once the child completes")
    var outcome = driver^.finish()
    check(Bool(outcome) and outcome.value().is_ok(), "the owner completes")
    check(value_of(outcome.take()._take_ok()) == 7, "the join observes the value another fiber delivered")


@fieldwise_init
struct Mark(OnceUnary):
    var cleanups: ArcPointer[Int]
    comptime Arg = NoneType
    comptime Out = NoneType

    def call_once(deinit self, var unit: NoneType) -> NoneType:
        self.cleanups[] += 1
        return None


def guarded(cleanups: ArcPointer[Int]) -> IO[Int, Int]:
    """Wait forever; cleanup suspends once before it records itself."""
    return IO[Int, Int].never().guarantee(IO[NoneType, Int].cede().map(Mark(cleanups.copy())))


@fieldwise_init
struct CancelThenJoin(OnceUnary):
    var cleanups: ArcPointer[Int]
    var seen: ArcPointer[Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        # One yield lets the child enter its guarded wait before the request.
        return IO[NoneType, Int].cede().flat_map(CancelAfterCede(fiber^, self.cleanups^, self.seen^))


@fieldwise_init
struct CancelAfterCede(OnceUnary):
    var fiber: Fiber[Int, Int]
    var cleanups: ArcPointer[Int]
    var seen: ArcPointer[Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        var canceling = self.fiber.cancel()
        return canceling^.flat_map(ReadThenJoin(self.fiber^, self.cleanups^, self.seen^))


@fieldwise_init
struct ReadThenJoin(OnceUnary):
    var fiber: Fiber[Int, Int]
    var cleanups: ArcPointer[Int]
    var seen: ArcPointer[Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        self.seen[] = self.cleanups[]
        return self.fiber^.join().map(Add(0))


def cancel_waits() raises:
    var cleanups = ArcPointer(0)
    var seen = ArcPointer(-1)
    var program = guarded(cleanups).start().flat_map(CancelThenJoin(cleanups.copy(), seen.copy()))
    check(value_of(run(program^)) == -2, "a canceled child joins as canceled")
    check(seen[] == 1, "cancel returns only after the child's cleanup finished")
    check(cleanups[] == 1, "cleanup ran once")


@fieldwise_init
struct JoinWith(OnceUnary):
    var mode: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        if self.mode == 0:
            return fiber^.join_with(IO[Int, Int].pure(5))
        return fiber^.join_with_never()


@fieldwise_init
struct RequestThenJoinWith(OnceUnary):
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        var request = fiber.request_cancel()
        return request^.flat_map(JoinWithFallback(fiber^))


@fieldwise_init
struct JoinWithFallback(OnceUnary):
    var fiber: Fiber[Int, Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return self.fiber^.join_with(IO[Int, Int].pure(5))


@fieldwise_init
struct UnitRequestThenJoin(OnceUnary):
    comptime Arg = Fiber[NoneType, Int]
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var fiber: Fiber[NoneType, Int]) -> IO[NoneType, Int]:
        var request = fiber.request_cancel()
        return request^.flat_map(UnitJoin(fiber^))


@fieldwise_init
struct UnitJoin(OnceUnary):
    var fiber: Fiber[NoneType, Int]
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        return self.fiber^.join_with_unit()


def ok_value(var outcome: Outcome[Int, Int]) -> Int:
    if not outcome:
        return -2
    var result = outcome.take()
    if result.is_ok():
        return result^._take_ok()
    var failure = result^._take_err()
    check(not failure.canceled, "an embedded child failure does not cancel the joiner")
    return -1000 - failure.errors.first()


def join_variants() raises:
    check(ok_value(run(IO[Int, Int].pure(3).start().flat_map(JoinWith(0)))) == 3, "join_with keeps a success")
    check(ok_value(run(IO[Int, Int].raise_error(4).start().flat_map(JoinWith(0)))) == -1004, "join_with re-raises a failure")
    check(ok_value(run(IO[Int, Int].never().start().flat_map(RequestThenJoinWith()))) == 5, "join_with replaces cancellation")
    check(ok_value(run(IO[Int, Int].pure(6).start().flat_map(JoinWith(1)))) == 6, "join_with_never keeps a success")
    var unit = run(IO[NoneType, Int].never().start().flat_map(UnitRequestThenJoin()))
    check(Bool(unit) and unit.value().is_ok(), "join_with_unit replaces cancellation with unit")


@fieldwise_init
struct StartInner(OnceUnary):
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var value: Int) -> IO[Int, Int]:
        return IO[Int, Int].pure(value * 10).start().flat_map(JoinAdd0()).map(Plus(value))


@fieldwise_init
struct JoinAdd0(OnceUnary):
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join().map(Add(0))


@fieldwise_init
struct Plus(OnceUnary):
    var base: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        return self.base + value


def nested() raises:
    var child = IO[Int, Int].pure(4).flat_map(StartInner())
    check(ok_value(run(child^.start().flat_map(JoinAdd0()))) == 44, "a fiber started by a fiber joins through its owner")


def main() raises:
    independent()
    parking_join()
    cancel_waits()
    join_variants()
    nested()
    print("fiber basics: independent progress, parking join, cancel waits for cleanup, join_with, nesting")
