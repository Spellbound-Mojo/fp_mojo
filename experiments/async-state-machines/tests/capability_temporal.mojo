"""Timing and Temporal: laws on virtual time, SyncIO timing, and forwarding through layers."""
from std.os import abort
from fp.algebra import flat_map, map, StringMonoid
from fp.callables import OnceThunk, OnceUnary
from fp.effects import (Outcome, SyncIO, OptionalT, StateT, WriterT, LiftConcurrent, LiftTiming, LiftTemporal,
    run_io, run as run_layer, delay, monotonic, timed, sleep, timeout_to, timeout_after, timeout, delay_by, and_wait,
    make_ref, update_ref, get_ref, start, cancel, join)
from fp.effects.async_runtime import IO, Async, Ref, Fiber, Duration, Instant, TestControl
from fp.effects.async_runtime.protocols import Machine

comptime A = Async[Int]


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def ms(value: Int) -> Duration:
    try:
        return Duration.milliseconds(value)
    except:
        abort("a valid duration")


def nanos(duration: Duration) -> Int:
    return duration.to_nanoseconds()


def virtual[P: Machine](var program: P) -> Outcome[P.Value, P.Error]:
    """Run on virtual time, advancing to each next deadline once nothing is runnable."""
    var control = TestControl(program^)
    control.tick_all()
    if not control.is_completed():
        abort("a virtual-time program waits for nothing it can reach")
    return control^.results()


def value_of[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    if not outcome or not outcome.value().is_ok():
        abort("expected a success")
    return outcome.take()._take_ok()


def failure_of[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> Int:
    if not outcome:
        return -2
    var result = outcome.take()
    if result.is_ok():
        return 0
    return -1000 - result^._take_err().errors.first()


def three(var unit: NoneType) -> Int:
    return 3


@fieldwise_init
struct Then(OnceUnary):
    """Sleep for a second duration after the first."""
    var duration: Duration
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        return sleep[A](self.duration)


def laws() raises:
    var slept = value_of(virtual(timed[A](sleep[A](ms(3)).flat_map(Then(ms(4))))))
    check(nanos(slept[0]) == 7_000_000, "sleep(a) then sleep(b) advances the clock by a + b")

    var fallback = value_of(virtual(timed[A](timeout_to[A](IO[Int, Int].never(), ms(5), IO[Int, Int].pure(7)))))
    check(fallback[1] == 7 and nanos(fallback[0]) == 5_000_000, "timeout_to(never, d, f) runs f after d")

    var winner = value_of(virtual(timed[A](timeout_to[A](sleep[A](ms(1)).map(three), ms(5), IO[Int, Int].pure(7)))))
    check(winner[1] == 3 and nanos(winner[0]) == 1_000_000, "a value before the deadline wins")

    var after = value_of(virtual(timeout_after[A](sleep[A](ms(9)).map(three), ms(2), IO[Int, Int].pure(8))))
    check(after == 8, "timeout_after falls back by first terminal outcome")

    check(failure_of(virtual(timeout[A](IO[Int, Int].never(), ms(2), 9))) == -1009, "timeout raises its error")

    var delayed = value_of(virtual(timed[A](delay_by[A](IO[Int, Int].pure(4), ms(2)))))
    check(delayed[1] == 4 and nanos(delayed[0]) == 2_000_000, "delay_by sleeps first")
    var waited = value_of(virtual(timed[A](and_wait[A](IO[Int, Int].pure(5), ms(3)))))
    check(waited[1] == 5 and nanos(waited[0]) == 3_000_000, "and_wait sleeps after, keeping the value")


@fieldwise_init
struct CancelSleep(OnceUnary):
    comptime Arg = Fiber[NoneType, Int]
    comptime Out = IO[Outcome[NoneType, Int], Int]

    def call_once(deinit self, var fiber: Fiber[NoneType, Int]) -> IO[Outcome[NoneType, Int], Int]:
        var stopping = cancel[A, NoneType](fiber)
        return stopping^.flat_map(JoinAfter(fiber^))


@fieldwise_init
struct JoinAfter(OnceUnary):
    var fiber: Fiber[NoneType, Int]
    comptime Arg = NoneType
    comptime Out = IO[Outcome[NoneType, Int], Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Outcome[NoneType, Int], Int]:
        return join[A, NoneType](self.fiber^)


@fieldwise_init
struct Second(OnceUnary):
    """Read the clock again after a yield and compare."""
    comptime Arg = Instant
    comptime Out = IO[Bool, Int]

    def call_once(deinit self, var first: Instant) -> IO[Bool, Int]:
        return IO[NoneType, Int].cede().flat_map(Compare(first^))


@fieldwise_init
struct Compare(OnceUnary):
    var first: Instant
    comptime Arg = NoneType
    comptime Out = IO[Bool, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Bool, Int]:
        return monotonic[A]().map(NotEarlier(self.first^))


@fieldwise_init
struct NotEarlier(OnceUnary):
    var first: Instant
    comptime Arg = Instant
    comptime Out = Bool

    def call_once(deinit self, var second: Instant) -> Bool:
        return second >= self.first


def clock_reads() raises:
    var canceled = value_of(virtual(timed[A](start[A](sleep[A](ms(10))).flat_map(CancelSleep()))))
    check(not canceled[1] and nanos(canceled[0]) == 0, "a canceled sleep completes without advancing time")
    check(value_of(virtual(monotonic[A]().flat_map(Second()))), "monotonic never decreases")


@fieldwise_init
struct Seven(OnceThunk):
    comptime Out = Int
    comptime Error = Never

    def call_once(deinit self) -> Int:
        return 7


def sync_timing() raises:
    var measured = run_io(timed[SyncIO[Int]](delay[SyncIO[Int]](Seven())))
    check(Bool(measured) and measured.value().is_ok(), "SyncIO measures a program")
    check(measured.take()._take_ok()[1] == 7, "SyncIO's timed keeps the value")
    check(Bool(run_io(monotonic[SyncIO[Int]]())), "SyncIO reads its context's clock")


comptime O = OptionalT[A]
comptime OT = LiftTemporal[O, A]


def bump(var value: Int) -> Int:
    return value + 1


@fieldwise_init
struct BumpThenRead(OnceUnary):
    comptime Arg = Ref[Int]
    comptime Out = IO[Optional[Int], Int]

    def call_once(deinit self, var cell: Ref[Int]) -> IO[Optional[Int], Int]:
        return flat_map[O](update_ref[OT](cell, bump), ReadAfter(cell.copy()))


@fieldwise_init
struct ReadAfter(OnceUnary):
    var cell: Ref[Int]
    comptime Arg = NoneType
    comptime Out = IO[Optional[Int], Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Optional[Int], Int]:
        return get_ref[OT, Int](self.cell)


def layers() raises:
    var counted = value_of(virtual(flat_map[O](make_ref[OT](1), BumpThenRead())))
    check(counted == Optional(2), "Concurrent through OptionalT shares the base cell")

    var present = value_of(virtual(timed[OT](and_wait[OT](IO[Optional[Int], Int].pure(Optional(5)), ms(2)))))
    check(Bool(present) and present.value()[1] == 5 and nanos(present.value()[0]) == 2_000_000, "and_wait and timed through OptionalT")
    var absent = value_of(virtual(timed[A](and_wait[OT](IO[Optional[Int], Int].pure(Optional[Int]()), ms(2)))))
    check(not absent[1] and nanos(absent[0]) == 0, "a layer's absence skips the sleep after it")
    var untimed = value_of(virtual(timed[OT](IO[Optional[Int], Int].pure(Optional[Int]()))))
    check(not untimed, "a layer's absence has no duration")

    var raced = value_of(virtual(timeout_to[OT](IO[Optional[Int], Int].never(), ms(3), IO[Optional[Int], Int].pure(Optional(6)))))
    check(raced == Optional(6), "timeout_to forwards layer programs to the base")
    var lifted = value_of(virtual(timed[A](sleep[OT](ms(4)))))
    check(Bool(lifted[1]) and nanos(lifted[0]) == 4_000_000, "sleep through OptionalT")

    comptime S = StateT[A, Int]
    var stateful = value_of(virtual(run_layer[S](timed[LiftTiming[S, A]](monotonic[LiftTiming[S, A]]()), 3)))
    check(stateful[1] == 3, "Timing through StateT keeps the state")

    comptime W = WriterT[A, StringMonoid]
    var written = value_of(virtual(run_layer[W](timed[LiftTiming[W, A]](monotonic[LiftTiming[W, A]]()))))
    check(written[0] == "" and nanos(written[1][0]) == 0, "Timing through WriterT logs nothing")


def main() raises:
    laws()
    clock_reads()
    sync_timing()
    layers()
    print("capability temporal: sleep, timeout and delay laws on virtual time, monotonic reads, SyncIO timing, layer forwarding")
