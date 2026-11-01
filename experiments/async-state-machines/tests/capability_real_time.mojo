"""Wall-clock time: SystemTime, real_time on Async and SyncIO, layer forwarding, and TestControl's epoch."""
from std.os import abort
from fp.algebra import StringMonoid
from fp.callables import OnceUnary
from fp.effects import (Outcome, SyncIO, OptionalT, StateT, WriterT, LiftTiming, LiftTemporal,
    run_io, run as run_layer, monotonic, real_time, sleep, delay_by)
from fp.effects.async_runtime import IO, Async, Duration, Instant, SystemTime, TestControl, run
from fp.effects.async_runtime.protocols import Machine

comptime A = Async[Int]
# 2020-01-01T00:00:00Z: any system reading is later.
comptime RECENT = 1577836800


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def ms(value: Int) -> Duration:
    try:
        return Duration.milliseconds(value)
    except:
        abort("a valid duration")


def text(time: SystemTime) -> String:
    return String(time)


def value_of[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    if not outcome or not outcome.value().is_ok():
        abort("expected a success")
    return outcome.take()._take_ok()


def virtual[P: Machine](var program: P) -> Outcome[P.Value, P.Error]:
    var control = TestControl(program^)
    control.tick_all()
    if not control.is_completed():
        abort("a virtual-time program waits for nothing it can reach")
    return control^.results()


def system_time() raises:
    check(SystemTime() == SystemTime.nanoseconds(0) and text(SystemTime()) == "1970-01-01T00:00:00Z", "the default is the epoch")
    var moment = SystemTime.seconds(1700000000)
    check(moment.to_nanoseconds() == 1700000000_000000000 and moment.to_seconds() == 1700000000, "seconds round-trip")
    check(text(moment) == "2023-11-14T22:13:20Z", "RFC 3339 without a zero fraction")
    check(text(SystemTime.nanoseconds(1700000000_000000001)) == "2023-11-14T22:13:20.000000001Z", "nine fractional digits")
    check(text(SystemTime.seconds(951782400)) == "2000-02-29T00:00:00Z", "a leap day")
    var before = SystemTime.nanoseconds(-1)
    check(before.to_seconds() == -1 and text(before) == "1969-12-31T23:59:59.999999999Z", "before the epoch floors")
    check(text(SystemTime.nanoseconds(Int.MAX)) == "2262-04-11T23:47:16.854775807Z", "the latest time")
    check(text(SystemTime.nanoseconds(Int.MIN)) == "1677-09-21T00:12:43.145224192Z", "the earliest time")

    check(before < SystemTime() and SystemTime() <= SystemTime() and moment > SystemTime() and moment != before, "comparison")
    var later = moment + ms(1500)
    check(later.to_nanoseconds() == 1700000001_500000000 and later - ms(1500) == moment, "Duration arithmetic")
    check(later.after(ms(1)) == later + ms(1) and later.before(ms(1)) == later - ms(1), "operators delegate")
    var elapsed = later.since(moment)
    check(Bool(elapsed) and elapsed.value().to_nanoseconds() == 1_500_000_000, "since measures a later time")
    check(not moment.since(later), "since reports a wall clock stepped back as None")
    check(SystemTime.nanoseconds(5).since(before).value().to_nanoseconds() == 6, "since across the epoch")
    var widest = SystemTime.nanoseconds(Int.MAX).since(SystemTime.nanoseconds(Int.MIN))
    check(widest.value().to_nanoseconds() == 1_000_000_000_000_000_000, "since saturates at the largest Duration")

    var failures = 0
    try:
        _ = SystemTime.nanoseconds(Int.MAX) + Duration.nanoseconds(1)
    except:
        failures += 1
    try:
        _ = SystemTime.nanoseconds(Int.MIN) - Duration.nanoseconds(1)
    except:
        failures += 1
    try:
        _ = SystemTime.seconds(Int.MAX // 1000000000 + 1)
    except:
        failures += 1
    check(failures == 3, "out-of-range results raise")


def system_clock() raises:
    var async_read = value_of(run(real_time[A]()))
    check(async_read.to_seconds() > RECENT, "Async reads CLOCK_REALTIME")
    var io_read = value_of(run(IO[SystemTime, Int].real_time()))
    check(io_read.to_seconds() > RECENT, "IO.real_time reads CLOCK_REALTIME")
    var sync_read = run_io(real_time[SyncIO[Int]]())
    check(Bool(sync_read) and sync_read.value().is_ok(), "SyncIO reads its context's wall clock")
    check(sync_read.take()._take_ok().to_seconds() > RECENT, "SyncIO reads CLOCK_REALTIME")


@fieldwise_init
struct ReadAfter(OnceUnary):
    """Read the wall clock after a sleep, keeping earlier readings."""
    var duration: Duration
    comptime Arg = List[SystemTime]
    comptime Out = IO[List[SystemTime], Int]

    def call_once(deinit self, var readings: List[SystemTime]) -> IO[List[SystemTime], Int]:
        return sleep[A](self.duration).flat_map(Read(readings^))


@fieldwise_init
struct Read(OnceUnary):
    var readings: List[SystemTime]
    comptime Arg = NoneType
    comptime Out = IO[List[SystemTime], Int]

    def call_once(deinit self, var unit: NoneType) -> IO[List[SystemTime], Int]:
        return real_time[A]().map(Append(self.readings^))


@fieldwise_init
struct Append(OnceUnary):
    var readings: List[SystemTime]
    comptime Arg = SystemTime
    comptime Out = List[SystemTime]

    def call_once(deinit self, var time: SystemTime) -> List[SystemTime]:
        var readings = self.readings^
        readings.append(time^)
        return readings^


def nanos_of(readings: List[SystemTime], index: Int) -> Int:
    return readings[index].to_nanoseconds()


def test_control() raises:
    var start = value_of(virtual(real_time[A]()))
    check(start == SystemTime(), "TestControl's wall clock starts at the epoch")

    # sleep 5, read, sleep 20, read: tick_for stops between the two deadlines.
    var program = sleep[A](ms(5)).flat_map(Read(List[SystemTime]())).flat_map(ReadAfter(ms(20)))
    var control = TestControl(program^)
    control.tick_for(ms(12))
    check(not control.is_completed(), "tick_for stops before the second deadline")
    control.advance(ms(13))
    control.tick()
    check(control.is_completed(), "advance reaches the second deadline")
    var stepped = value_of(control^.results())
    check(len(stepped) == 2 and nanos_of(stepped, 0) == 5_000_000, "tick_for moves the wall clock to each deadline")
    check(nanos_of(stepped, 1) == 25_000_000, "advance moves the wall clock")

    var all = value_of(virtual(sleep[A](ms(7)).flat_map(Read(List[SystemTime]()))))
    check(nanos_of(all, 0) == 7_000_000, "tick_all moves the wall clock")


@fieldwise_init
struct Pair(OnceUnary):
    """Read both clocks."""
    var earlier: List[Instant]
    var earlier_real: List[SystemTime]
    comptime Arg = NoneType
    comptime Out = IO[Tuple[List[Instant], List[SystemTime]], Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Tuple[List[Instant], List[SystemTime]], Int]:
        return monotonic[A]().flat_map(PairReal(self.earlier^, self.earlier_real^))


@fieldwise_init
struct PairReal(OnceUnary):
    var earlier: List[Instant]
    var earlier_real: List[SystemTime]
    comptime Arg = Instant
    comptime Out = IO[Tuple[List[Instant], List[SystemTime]], Int]

    def call_once(deinit self, var instant: Instant) -> IO[Tuple[List[Instant], List[SystemTime]], Int]:
        var instants = self.earlier^
        instants.append(instant^)
        return real_time[A]().map(PairDone(instants^, self.earlier_real^))


@fieldwise_init
struct PairDone(OnceUnary):
    var instants: List[Instant]
    var times: List[SystemTime]
    comptime Arg = SystemTime
    comptime Out = Tuple[List[Instant], List[SystemTime]]

    def call_once(deinit self, var time: SystemTime) -> Tuple[List[Instant], List[SystemTime]]:
        var times = self.times^
        times.append(time^)
        return (self.instants^, times^)


@fieldwise_init
struct SleepThenPair(OnceUnary):
    var duration: Duration
    comptime Arg = Tuple[List[Instant], List[SystemTime]]
    comptime Out = IO[Tuple[List[Instant], List[SystemTime]], Int]

    def call_once(deinit self, var first: Tuple[List[Instant], List[SystemTime]]) -> IO[Tuple[List[Instant], List[SystemTime]], Int]:
        return sleep[A](self.duration).flat_map(Pair(first[0].copy(), first[1].copy()))


def consistency() raises:
    var program = Pair(List[Instant](), List[SystemTime]()).call_once(None).flat_map(SleepThenPair(ms(7)))
    var read = value_of(virtual(program^))
    var instants = read[0].copy()
    var times = read[1].copy()
    var monotonic_elapsed = instants[1].since(instants[0]).to_nanoseconds()
    var real_elapsed = times[1].since(times[0])
    check(monotonic_elapsed == 7_000_000 and Bool(real_elapsed) and real_elapsed.value().to_nanoseconds() == monotonic_elapsed,
        "monotonic and wall-clock time move together on virtual time")
    check(times[0].to_nanoseconds() == instants[0].since(Instant()).to_nanoseconds(), "a manual wall clock is the epoch plus its monotonic reading")


comptime O = OptionalT[A]
comptime OT = LiftTemporal[O, A]
comptime OL = LiftTiming[O, A]


def layers() raises:
    var optional = value_of(virtual(delay_by[OT](real_time[OT](), ms(4))))
    check(Bool(optional) and optional.value().to_nanoseconds() == 4_000_000, "real_time through LiftTemporal over OptionalT")
    var timing = value_of(virtual(real_time[OL]()))
    check(Bool(timing) and timing.value() == SystemTime(), "real_time through LiftTiming over OptionalT")

    comptime S = StateT[A, Int]
    var stateful = value_of(virtual(run_layer[S](real_time[LiftTiming[S, A]](), 3)))
    check(stateful[0] == SystemTime() and stateful[1] == 3, "real_time through StateT keeps the state")

    comptime W = WriterT[A, StringMonoid]
    var written = value_of(virtual(run_layer[W](real_time[LiftTiming[W, A]]())))
    check(written[0] == "" and written[1] == SystemTime(), "real_time through WriterT logs nothing")

    comptime SS = StateT[SyncIO[Int].Family, Int]
    var sync_layer = run_io(run_layer[SS](real_time[LiftTiming[SS, SyncIO[Int]]](), 4))
    check(Bool(sync_layer) and sync_layer.value().is_ok(), "real_time through StateT over SyncIO")
    var sync_pair = sync_layer.take()._take_ok()
    check(sync_pair[0].to_seconds() > RECENT and sync_pair[1] == 4, "the lifted SyncIO reading is CLOCK_REALTIME")


def main() raises:
    system_time()
    system_clock()
    test_control()
    consistency()
    layers()
    print("capability real time: SystemTime arithmetic and RFC 3339, real_time on Async and SyncIO, TestControl epoch, clock consistency, layer forwarding")
