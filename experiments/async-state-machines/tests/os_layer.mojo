"""Private POSIX layer: pipes, nonblocking reads, poll, clocks, sleep, processors, CPU time and threads."""
from std.atomic import Atomic
from std.ffi import ErrNo
from std.memory import ArcPointer
from std.os import abort
from fp._internal.os import (
    CLOCK_MONOTONIC, CLOCK_REALTIME, OSThread, POLLIN, POLLOUT, Pipe, PollFd, RUSAGE_SELF, RUSAGE_THREAD,
    clock_gettime, getrusage, is_close_on_exec, is_nonblocking, monotonic_nanoseconds, nanosleep,
    online_processors, poll, read, realtime_nanoseconds, set_close_on_exec, set_nonblocking, write,
)

comptime millisecond = 1_000_000


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def message_bytes() -> List[UInt8]:
    var result = List[UInt8]()
    for byte in "hello, pipe".as_bytes():
        result.append(byte)
    return result^


def pipe_round_trip() raises:
    var pipe = Pipe.open()
    check(pipe.read_end.fd >= 0 and pipe.write_end.fd >= 0 and pipe.read_end.fd != pipe.write_end.fd, "pipe descriptors")
    check(not is_nonblocking(pipe.read_end.fd) and not is_close_on_exec(pipe.write_end.fd), "pipe() ends start blocking and inheritable")
    var message = message_bytes()
    check(write(pipe.write_end.fd, Span(message)) == len(message), "whole write")
    var buffer = List[UInt8](length=64, fill=0)
    var count = read(pipe.read_end.fd, Span(buffer))
    check(count == len(message), "read length")
    for i in range(count):
        check(buffer[i] == message[i], "read contents")
    _ = write(pipe.write_end.fd, Span(message))
    # Dropping the write end closes it: the buffered bytes, then end of file.
    var read_end = pipe^.into_read_end()
    check(read(read_end.fd, Span(buffer)) == len(message), "buffered bytes survive the writer")
    check(read(read_end.fd, Span(buffer)) == 0, "end of file after the writer closes")
    read_end^.close()
    print("pipe round trip: ok")


def nonblocking() raises:
    var pipe = Pipe.open_self_pipe()
    check(is_nonblocking(pipe.read_end.fd) and is_nonblocking(pipe.write_end.fd), "self-pipe ends are nonblocking")
    check(is_close_on_exec(pipe.read_end.fd) and is_close_on_exec(pipe.write_end.fd), "self-pipe ends are close-on-exec")
    var buffer = List[UInt8](length=8, fill=0)
    try:
        _ = read(pipe.read_end.fd, Span(buffer))
        abort("an empty nonblocking pipe must not read")
    except error:
        check(error.errno == ErrNo.EAGAIN and error.is_again() and error.call == "read", "empty read reports EAGAIN")
    check(pipe.wake() and pipe.drain() == 1 and pipe.drain() == 0, "one wake, one drained byte")
    # Wakes coalesce once the pipe is full; draining discards every byte.
    var written = 0
    while pipe.wake():
        written += 1
    check(written >= 4096 and pipe.drain() == written, "a full pipe absorbs further wakes")
    # Flags toggle without disturbing each other.
    set_nonblocking(pipe.read_end.fd, False)
    check(not is_nonblocking(pipe.read_end.fd) and is_close_on_exec(pipe.read_end.fd), "clear O_NONBLOCK only")
    set_close_on_exec(pipe.read_end.fd, False)
    check(not is_close_on_exec(pipe.read_end.fd), "clear FD_CLOEXEC")
    set_nonblocking(pipe.read_end.fd)
    set_close_on_exec(pipe.read_end.fd)
    check(is_nonblocking(pipe.read_end.fd) and is_close_on_exec(pipe.read_end.fd), "set both flags again")
    try:
        _ = is_nonblocking(-1)
        abort("fcntl on an invalid descriptor must fail")
    except error:
        check(String(error) == "fcntl failed: errno 9", "EBADF is reported with the call name")
    print("nonblocking reads: ok")


def polling() raises:
    var pipe = Pipe.open_self_pipe()
    var interest = List[PollFd]()
    interest.append(PollFd(pipe.read_end.fd, POLLIN))
    interest.append(PollFd(pipe.write_end.fd, POLLOUT))
    interest.append(PollFd(-1, POLLIN))
    check(poll(interest, 0) == 1, "only the write end is ready")
    check(not interest[0].ready() and interest[1].writable() and not interest[1].failed() and not interest[2].ready(), "write readiness")
    _ = pipe.wake()
    check(poll(interest, -1) == 2, "a wake makes the read end ready")
    check(interest[0].readable() and not interest[0].writable(), "read readiness")
    _ = pipe.drain()
    # Timeout: read interest alone with nothing written.
    var idle = List[PollFd]()
    idle.append(PollFd(pipe.read_end.fd, POLLIN))
    var started = monotonic_nanoseconds()
    check(poll(idle, 30) == 0 and not idle[0].ready(), "expiry reports no descriptors")
    check(monotonic_nanoseconds() - started >= 30 * millisecond, "the timeout elapses before expiry")
    # Hang-up: the read end becomes readable when the writer closes.
    var read_end = pipe^.into_read_end()
    idle[0] = PollFd(read_end.fd, POLLIN)
    check(poll(idle, 1000) == 1 and idle[0].readable() and not idle[0].failed(), "hang-up is readable")
    # Mojo destroys a value after its last use: keep the owner alive past poll.
    read_end^.close()
    print("poll readiness and timeout: ok")


def clocks() raises:
    var first = monotonic_nanoseconds()
    var second = clock_gettime(CLOCK_MONOTONIC)
    check(0 <= Int(second.nanoseconds) < 1_000_000_000 and second.total_nanoseconds() >= first, "monotonic clock")
    # 2026-01-01T00:00:00Z; the wall clock agrees with clock_gettime.
    var wall = realtime_nanoseconds()
    check(wall > 1_767_225_600 * 1_000_000_000, "realtime counts from the Unix epoch")
    check(clock_gettime(CLOCK_REALTIME).total_nanoseconds() - wall < 1000 * millisecond, "both realtime reads agree")
    try:
        _ = clock_gettime(12345)
        abort("an unknown clock must fail")
    except error:
        check(error.errno == ErrNo.EINVAL and error.call == "clock_gettime", "unknown clock reports EINVAL")
    var started = monotonic_nanoseconds()
    nanosleep(20 * millisecond)
    check(monotonic_nanoseconds() - started >= 20 * millisecond, "nanosleep sleeps at least its duration")
    nanosleep(0)
    nanosleep(-1)
    print("clocks and nanosleep: ok")


def processors_and_cpu_time() raises:
    check(online_processors() >= 1, "at least one processor is online")
    # Idle: sleeping costs the thread almost no CPU time.
    var before = getrusage(RUSAGE_THREAD)
    nanosleep(200 * millisecond)
    var idle = getrusage(RUSAGE_THREAD).total_nanoseconds() - before.total_nanoseconds()
    check(0 <= idle < 50 * millisecond, String("an idle thread uses no CPU: ", idle, " ns"))
    # Busy: spinning on the clock is charged to this thread and the process.
    var spin_until = monotonic_nanoseconds() + 100 * millisecond
    while monotonic_nanoseconds() < spin_until:
        pass
    var busy = getrusage(RUSAGE_THREAD)
    check(busy.total_nanoseconds() - before.total_nanoseconds() >= 50 * millisecond, "spinning is charged to the thread")
    check(getrusage(RUSAGE_SELF).total_nanoseconds() >= busy.total_nanoseconds(), "the process includes its threads")
    print("processor count and getrusage: ok")


@fieldwise_init
struct Work(Movable):
    var shared: ArcPointer[Atomic[Int64]]
    var steps: Int
    var finished: Atomic[Int64]


def body(state: Pointer[Work, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    nanosleep(5 * millisecond)
    for _ in range(state[].steps):
        _ = state[].shared[].fetch_add(1)
    state[].finished.store(1)
    return None


def start(state: ArcPointer[Work]) raises -> OSThread:
    return OSThread(body, Pointer[Work, MutAnyOrigin](to=state[]))


def threads() raises:
    var shared = ArcPointer(Atomic[Int64](0))
    var states = List[ArcPointer[Work]]()
    var workers = List[OSThread]()
    for _ in range(4):
        states.append(ArcPointer(Work(shared.copy(), 10_000, Atomic[Int64](0))))
        workers.append(start(states[len(states) - 1]))
    while len(workers) > 0:
        workers.pop().join()
    for state in states:
        check(state[].finished.load() == 1, "join waits for the body")
    check(shared[].load() == 40_000, "every thread ran to completion")
    # Dropping an unjoined owner joins it; the state outlives the thread.
    var observed = ArcPointer(Atomic[Int64](0))
    var state = ArcPointer(Work(observed.copy(), 1, Atomic[Int64](0)))
    var dropped = start(state)
    _ = dropped^
    check(state[].finished.load() == 1 and observed[].load() == 1, "dropping joins the thread")
    print("threads through the shared owner: ok")


def main() raises:
    pipe_round_trip()
    nonblocking()
    polling()
    clocks()
    processors_and_cpu_time()
    threads()
