"""`await_readable` and `await_writable` on the root's poller, with `Driver.poll` and `Driver.park`.

- Pipes: a read waits for a byte written by another thread; a write waits for
  room in a full pipe; hang-up counts as ready.
- Cancellation, directly or through a timeout, removes the registration.
- `Driver.poll` finds readiness without waiting.
- `Driver.park` returns at once when work is runnable, and otherwise wakes on
  readiness, a deadline, an external wake from another thread, or its timeout.
- Under TestControl, readiness is seen at the next tick.
"""
from std.atomic import Atomic
from std.memory import ArcPointer
from std.os import abort
from std.time import monotonic
from fp.callables import OnceUnary
from fp.data import Result, Ok
from fp.effects import IOContext, CancellationToken, Outcome, EffectFailure, unsafe_start
from fp.effects import Fiber as Thread
from fp.effects import IO as SyncIO
from fp.effects.protocols import ReaderAction
from fp.effects.async_runtime import IO, Clock, Driver, Duration, Progress, TestControl, OSError, run
from fp.effects.async_runtime.protocols import Machine, await_readable, await_writable
from fp._internal.os import Pipe, OwnedFd, read, write
from fp.effects._async.polling import _existing_root_poller

comptime PROMPT_NS = 2_000_000_000


def check(condition: Bool, message: String):
    if not condition:
        abort(String("descriptor readiness: ", message))


def spin(nanoseconds: Int):
    var end = Int(monotonic()) + nanoseconds
    while Int(monotonic()) < end:
        pass


def milliseconds(count: Int) -> Duration:
    var duration = Duration()
    duration._nanoseconds = count * 1_000_000
    return duration^


def descriptor(fd: OwnedFd) -> RawFileDescriptor:
    return RawFileDescriptor(Int32(fd.fd))


def put_byte(fd: OwnedFd):
    var byte = List[UInt8](length=1, fill=7)
    try:
        check(write(fd.fd, Span(byte)) == 1, "one byte written")
    except:
        abort("descriptor readiness: write failed")


def take_byte(fd: OwnedFd) -> Int:
    var byte = List[UInt8](length=1, fill=0)
    try:
        return read(fd.fd, Span(byte))
    except error:
        if error.is_again():
            return 0
        abort("descriptor readiness: read failed")


def fill(fd: OwnedFd) -> Int:
    """Write until a nonblocking pipe is full; returns the bytes written."""
    var chunk = List[UInt8](length=4096, fill=1)
    var total = 0
    while True:
        try:
            total += write(fd.fd, Span(chunk))
        except error:
            check(error.is_again(), "a full pipe reports EAGAIN")
            return total


def drain_all(fd: OwnedFd):
    while take_byte(fd) > 0:
        pass


def registrations[P: Machine](driver: Driver[P]) -> Bool:
    var poller = _existing_root_poller(driver._driver.task._executor.scheduler)
    return Bool(poller) and poller.value()[].has_registrations()


def park_for[P: Machine](mut driver: Driver[P], timeout: Optional[Duration] = None):
    # Driver is linear: a raising call must not leave it abandoned.
    try:
        driver.park(timeout)
    except error:
        abort(String("descriptor readiness: park failed: ", error))


def observe[P: Machine](mut driver: Driver[P]) -> Progress:
    try:
        return driver.poll(0)
    except:
        abort("descriptor readiness: a zero budget is accepted")


def advance(clock: Clock, duration: Duration):
    try:
        clock.advance_to(clock.now() + duration)
    except:
        abort("descriptor readiness: manual clock advance")


def settle[P: Machine](mut driver: Driver[P]):
    """Poll until nothing is runnable, without parking."""
    while True:
        var progress = driver.poll()
        if progress.completed or not progress.runnable:
            return


def finish_ok[P: Machine](var driver: Driver[P], message: String) where P.Error == Int:
    var outcome = driver^.finish()
    check(Bool(outcome) and outcome.value().is_ok(), message)


# ===------------------------------------------------------------------=== #
# Threads
# ===------------------------------------------------------------------=== #


struct Writer(ReaderAction):
    """Runs on an OS thread: wait, then write one byte, or drain, or cancel."""
    var fd: Int32
    var delay: Int
    var drain: Bool
    var token: Optional[CancellationToken]
    comptime Family = SyncIO[Error]
    comptime Env = IOContext[Error]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Error]

    def __init__(out self, fd: Int32, delay: Int, drain: Bool = False):
        self.fd = fd
        self.delay = delay
        self.drain = drain
        self.token = None

    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        spin(self.delay)
        if self.token:
            self.token.value().cancel()
        else:
            var buffer = List[UInt8](length=4096, fill=1)
            try:
                if self.drain:
                    _ = read(self.fd, Span(buffer))
                else:
                    _ = write(self.fd, Span(buffer)[:1])
            except:
                abort("descriptor readiness: the writer thread failed")
        var unit: NoneType = None
        return Optional(Result[NoneType, EffectFailure[Error]](Ok(unit)))


def start(var writer: Writer) -> Thread[Writer]:
    try:
        return unsafe_start(writer^)
    except:
        abort("descriptor readiness: unsafe_start failed")


@fieldwise_init
struct ReadOne(OnceUnary):
    """After readiness, read the byte, which must be there."""
    var fd: Int32
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        var byte = List[UInt8](length=1, fill=0)
        try:
            return read(self.fd, Span(byte))
        except:
            abort("descriptor readiness: readable but the read failed")


# ===------------------------------------------------------------------=== #
# Cases
# ===------------------------------------------------------------------=== #


def pipes() raises:
    var pipe = Pipe.open_self_pipe()
    var fd = pipe.read_end.fd
    # A byte from another thread wakes a parked run.
    for delay in range(0, 3_000_001, 500_000):
        var thread = start(Writer(pipe.write_end.fd, delay))
        var outcome = run(await_readable[Int](descriptor(pipe.read_end)).map(ReadOne(fd)))
        check(Bool(outcome) and outcome.take()._take_ok() == 1, "a readable pipe yields its byte")
        check(Bool(thread^.join()), "the writer finished")
    # An empty pipe is writable at once.
    var written = run(await_writable[Int](descriptor(pipe.write_end)))
    check(Bool(written) and written.value().is_ok(), "an empty pipe is writable")
    # A full pipe becomes writable when another thread drains it.
    var full = fill(pipe.write_end)
    check(full > 0, "the pipe filled")
    var thread = start(Writer(pipe.read_end.fd, 2_000_000, True))
    var room = run(await_writable[Int](descriptor(pipe.write_end)))
    check(Bool(room) and room.value().is_ok(), "a drained pipe is writable again")
    check(Bool(thread^.join()), "the drainer finished")
    drain_all(pipe.read_end)
    # Hang-up counts as ready.
    var other = Pipe.open_self_pipe()
    var reader = other^.into_read_end()
    var hung = run(await_readable[Int](descriptor(reader)))
    check(Bool(hung) and hung.value().is_ok(), "a hung-up pipe is readable")
    # Mojo closes a descriptor after its owner's last use: keep it open.
    _ = reader^
    _ = pipe^
    print("pipes: reads and writes wait for readiness from another thread; hang-up counts as ready")


def cancellation() raises:
    var pipe = Pipe.open_self_pipe()
    # Requested directly.
    var driver = Driver(await_readable[Int](descriptor(pipe.read_end)))
    settle(driver)
    check(registrations(driver), "a pending wait is registered")
    driver.request_cancel()
    settle(driver)
    check(not registrations(driver), "cancellation removes the registration")
    var progress = driver.poll()
    check(progress.completed, "the canceled wait completes")
    var outcome = driver^.finish()
    check(not outcome, "the wait completes canceled")
    # Through a timeout, on a manual clock.
    var clock = Clock.manual()
    var timed = Driver(await_readable[Int](descriptor(pipe.read_end)).timeout(milliseconds(5), 9), CancellationToken(), clock)
    settle(timed)
    check(registrations(timed), "the timed wait is registered")
    advance(clock, milliseconds(5))
    settle(timed)
    check(not registrations(timed), "the timeout removes the registration")
    var lost = timed^.finish()
    check(Bool(lost) and lost.value().is_err(), "the timeout wins")
    _ = pipe^
    print("cancellation: a canceled or timed-out wait removes its registration")


def poll_finds_readiness() raises:
    var pipe = Pipe.open_self_pipe()
    var driver = Driver(await_readable[Int](descriptor(pipe.read_end)).map(ReadOne(pipe.read_end.fd)))
    settle(driver)
    var idle = driver.poll()
    check(not idle.completed and not idle.runnable, "the wait is pending")
    put_byte(pipe.write_end)
    # No park: poll checks the poller without waiting while a descriptor is watched.
    var progress = driver.poll()
    check(progress.completed, "poll finds the ready descriptor itself")
    var outcome = driver^.finish()
    check(Bool(outcome) and outcome.take()._take_ok() == 1, "the byte is read")
    # A zero budget only observes.
    var observed = Driver(await_readable[Int](descriptor(pipe.read_end)))
    settle(observed)
    put_byte(pipe.write_end)
    var looked = observe(observed)
    check(not looked.completed, "a zero budget does not poll the descriptor")
    settle(observed)
    check(observed.poll().completed, "the next poll finds it")
    finish_ok(observed^, "the observed wait completes")
    drain_all(pipe.read_end)
    _ = pipe^
    print("poll: readiness is found without waiting whenever a descriptor is watched")


def park() raises:
    var pipe = Pipe.open_self_pipe()
    # Runnable: park returns at once.
    var runnable = Driver(IO[Int, Int].pure(1))
    var started = Int(monotonic())
    park_for(runnable, milliseconds(500))
    check(Int(monotonic()) - started < 200_000_000, "park returns at once while work is runnable")
    settle(runnable)
    park_for(runnable, milliseconds(500))
    finish_ok(runnable^, "a completed driver parks without waiting")
    # Readiness.
    var waiting = Driver(await_readable[Int](descriptor(pipe.read_end)).map(ReadOne(pipe.read_end.fd)))
    settle(waiting)
    var writer = start(Writer(pipe.write_end.fd, 20_000_000))
    started = Int(monotonic())
    park_for(waiting)
    var elapsed = Int(monotonic()) - started
    check(elapsed < PROMPT_NS, "park wakes on readiness")
    check(Bool(writer^.join()), "the writer finished")
    settle(waiting)
    finish_ok(waiting^, "the woken wait completes")
    # A deadline.
    var sleeping = Driver(IO[NoneType, Int].sleep(milliseconds(30)))
    settle(sleeping)
    started = Int(monotonic())
    while not sleeping.poll().completed:
        park_for(sleeping)
    elapsed = Int(monotonic()) - started
    check(elapsed >= 30_000_000 and elapsed < PROMPT_NS, "park waits until the deadline")
    finish_ok(sleeping^, "the sleep completes")
    # An external wake: another thread cancels the token.
    var token = CancellationToken()
    var forever = Driver(IO[Int, Int].never(), token, Clock())
    settle(forever)
    var canceler = Writer(0, 20_000_000)
    canceler.token = Optional(token.copy())
    var thread = start(canceler^)
    started = Int(monotonic())
    park_for(forever)
    check(Int(monotonic()) - started < PROMPT_NS, "park wakes on a foreign cancellation")
    check(Bool(thread^.join()), "the canceler finished")
    settle(forever)
    check(forever.poll().completed, "the canceled program completes")
    check(not forever^.finish(), "it completes canceled")
    # The host's timeout.
    var idle = Driver(IO[Int, Int].never())
    settle(idle)
    started = Int(monotonic())
    park_for(idle, milliseconds(10))
    elapsed = Int(monotonic()) - started
    check(elapsed >= 10_000_000 and elapsed < PROMPT_NS, "park honors the host's timeout")
    idle.request_cancel()
    settle(idle)
    check(not idle^.finish(), "the idle program completes canceled")
    _ = pipe^
    print("park: returns at once when runnable; wakes on readiness, deadlines, foreign wakes and its timeout")


def test_control() raises:
    var pipe = Pipe.open_self_pipe()
    var control = TestControl(await_readable[Int](descriptor(pipe.read_end)).map(ReadOne(pipe.read_end.fd)))
    control.tick()
    check(not control.is_completed(), "the wait is pending under virtual time")
    put_byte(pipe.write_end)
    control.tick()
    check(control.is_completed(), "readiness is seen at the next tick")
    var outcome = control^.results()
    check(Bool(outcome) and outcome.take()._take_ok() == 1, "the byte is read")
    _ = pipe^
    print("test control: readiness is observed at the next tick")


def main() raises:
    pipes()
    cancellation()
    poll_finds_readiness()
    park()
    test_control()
