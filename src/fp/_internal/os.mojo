"""Private POSIX layer: thin typed wrappers over operating-system calls.

The library calls POSIX directly only where the standard library lacks a
facility: descriptors and a self-pipe, `poll`, `clock_gettime` for the wall
clock, process and thread CPU time, and the joinable OS-thread owner shared by
`unsafe_start` and the blocking pool. Monotonic time is `std.time.monotonic()`,
processor counts are `std.sys.info.num_logical_cores()`, and sleeping is
`std.time.sleep`. Every wrapper is a single
external call plus the retry or error policy documented on it; no C sources.

Platform-dependent constants and structure layouts are selected at compile
time. Linux x86-64 values were checked against glibc's headers with
`offsetof`/`sizeof`; macOS values are from Darwin's public headers and are
unverified until macOS is qualified. Using a Linux-only facility on another
target is a compile-time error.
"""
from std.ffi import ErrNo, c_int, external_call, get_errno
from std.memory import ArcPointer
from std.os import abort
from std.time import monotonic
from std.sys.info import CompilationTarget, is_64bit, platform_map, size_of


comptime _linux_only = platform_map[T=Int, ...]


# ===------------------------------------------------------------------=== #
# Errors
# ===------------------------------------------------------------------=== #


@fieldwise_init
struct OSError(Copyable, Writable):
    """A failed POSIX call: its name and the error number it reported."""

    var call: StaticString
    var errno: ErrNo

    @staticmethod
    def last(call: StaticString) -> Self:
        """Capture the calling thread's errno for a call that just failed.

        Args:
            call: The failed function's name.

        Returns:
            The call and its errno.
        """
        return Self(call, get_errno())

    def is_again(self) -> Bool:
        """Report whether a nonblocking operation would have blocked.

        Returns:
            True for EAGAIN, which equals EWOULDBLOCK on Linux and macOS.
        """
        return self.errno == ErrNo.EAGAIN

    def write_to(self, mut writer: Some[Writer]):
        """Write the call and its error number.

        Args:
            writer: The destination.
        """
        writer.write(self.call, " failed: errno ", self.errno.value)


# ===------------------------------------------------------------------=== #
# Descriptors
# ===------------------------------------------------------------------=== #

# fcntl commands and flags. Linux x86-64 verified; macOS unverified.
comptime F_GETFD: c_int = 1
comptime F_SETFD: c_int = 2
comptime F_GETFL: c_int = 3
comptime F_SETFL: c_int = 4
comptime FD_CLOEXEC: c_int = 1
comptime O_NONBLOCK: c_int = c_int(platform_map[T=Int, "O_NONBLOCK", linux=0o4000, macos=0x0004]())
comptime _O_CLOEXEC: c_int = c_int(_linux_only["O_CLOEXEC", linux=0o2000000]())
"""Used only for pipe2 on Linux."""


def _fcntl(fd: c_int, command: c_int, argument: c_int) raises OSError -> c_int:
    # fcntl is variadic in C: only the first two arguments are fixed, which
    # matters for ABIs such as AAPCS on ARM64 macOS.
    var result = external_call["fcntl", c_int, num_fixed_args=2](fd, command, argument)
    if result == -1:
        raise OSError.last("fcntl")
    return result


def _update_flag(fd: c_int, get: c_int, set: c_int, flag: c_int, enabled: Bool) raises OSError:
    var flags = _fcntl(fd, get, 0)
    var updated = (flags | flag) if enabled else (flags & ~flag)
    if updated != flags:
        _ = _fcntl(fd, set, updated)


def is_nonblocking(fd: c_int) raises OSError -> Bool:
    """Report whether O_NONBLOCK is set in a descriptor's status flags.

    Args:
        fd: An open descriptor.

    Returns:
        True when reads and writes fail with EAGAIN instead of blocking.

    Raises:
        OSError: From fcntl(F_GETFL), such as EBADF.
    """
    return (_fcntl(fd, F_GETFL, 0) & O_NONBLOCK) != 0


def set_nonblocking(fd: c_int, enabled: Bool = True) raises OSError:
    """Set or clear O_NONBLOCK, preserving the other status flags.

    Args:
        fd: An open descriptor.
        enabled: Whether the descriptor should be nonblocking.

    Raises:
        OSError: From fcntl(F_GETFL) or fcntl(F_SETFL).
    """
    _update_flag(fd, F_GETFL, F_SETFL, O_NONBLOCK, enabled)


def is_close_on_exec(fd: c_int) raises OSError -> Bool:
    """Report whether FD_CLOEXEC is set in a descriptor's flags.

    Args:
        fd: An open descriptor.

    Returns:
        True when exec closes the descriptor.

    Raises:
        OSError: From fcntl(F_GETFD), such as EBADF.
    """
    return (_fcntl(fd, F_GETFD, 0) & FD_CLOEXEC) != 0


def set_close_on_exec(fd: c_int, enabled: Bool = True) raises OSError:
    """Set or clear FD_CLOEXEC, preserving the other descriptor flags.

    Args:
        fd: An open descriptor.
        enabled: Whether exec should close the descriptor.

    Raises:
        OSError: From fcntl(F_GETFD) or fcntl(F_SETFD).
    """
    _update_flag(fd, F_GETFD, F_SETFD, FD_CLOEXEC, enabled)


def read(fd: c_int, buffer: Span[mut=True, UInt8, _]) raises OSError -> Int:
    """Read at most the buffer's length, retrying when a signal interrupts.

    Args:
        fd: An open descriptor.
        buffer: The destination; its first bytes receive the data.

    Returns:
        The number of bytes read; zero at end of file or for an empty buffer.

    Raises:
        OSError: EAGAIN when a nonblocking descriptor has no data
            (`is_again()`), or another read error. EINTR is retried.
    """
    while True:
        var count = external_call["read", Int](fd, buffer.unsafe_ptr(), UInt(len(buffer)))
        if count >= 0:
            return count
        var error = OSError.last("read")
        if error.errno != ErrNo.EINTR:
            raise error^


def write(fd: c_int, data: Span[UInt8, _]) raises OSError -> Int:
    """Write at most the data's length, retrying when a signal interrupts.

    Args:
        fd: An open descriptor.
        data: The bytes to write.

    Returns:
        The number of bytes written, which can be fewer than requested.

    Raises:
        OSError: EAGAIN when a nonblocking descriptor is full (`is_again()`),
            EPIPE when no reader remains, or another write error. EINTR is
            retried.
    """
    while True:
        var count = external_call["write", Int](fd, data.unsafe_ptr(), UInt(len(data)))
        if count >= 0:
            return count
        var error = OSError.last("write")
        if error.errno != ErrNo.EINTR:
            raise error^


def close(fd: c_int) raises OSError:
    """Close a descriptor once; never retried.

    On Linux the descriptor is released even when close reports EINTR, and a
    retry could close a descriptor another thread has just opened.

    Args:
        fd: An open descriptor, which is invalid afterwards whatever the result.

    Raises:
        OSError: From close, such as EBADF or EIO.
    """
    if external_call["close", c_int](fd) != 0:
        raise OSError.last("close")


struct OwnedFd(Movable, Writable):
    """A descriptor closed exactly once, when its owner is dropped or closes it.

    Dropping ignores close errors, as the descriptor is released regardless;
    call `close` to observe them. Mojo destroys a value after its last use, so
    an owner whose raw `fd` is passed elsewhere, such as into a PollFd, must be
    used or closed explicitly after the last call that needs the descriptor.
    """

    var fd: c_int
    """The raw descriptor, valid while this value lives."""

    def __init__(out self, *, adopt: c_int):
        """Take ownership of an open descriptor.

        Args:
            adopt: A descriptor no other owner will close.
        """
        self.fd = adopt

    def __deinit__(deinit self):
        _ = external_call["close", c_int](self.fd)

    def close(deinit self) raises OSError:
        """Close now and report the result.

        Raises:
            OSError: From close; the descriptor is released regardless.
        """
        close(self.fd)

    def release(deinit self) -> c_int:
        """Give up ownership without closing.

        Returns:
            The descriptor, which the caller must close.
        """
        return self.fd

    def write_to(self, mut writer: Some[Writer]):
        """Write the descriptor number.

        Args:
            writer: The destination.
        """
        writer.write("fd ", self.fd)


struct Pipe(Movable):
    """Both ends of a pipe, each closed exactly once."""

    var read_end: OwnedFd
    """The end that reads."""
    var write_end: OwnedFd
    """The end that writes."""

    def __init__(out self, var read_end: OwnedFd, var write_end: OwnedFd):
        """Assemble a pipe from its owned ends.

        Args:
            read_end: The end that reads.
            write_end: The end that writes.
        """
        self.read_end = read_end^
        self.write_end = write_end^

    @staticmethod
    def open() raises OSError -> Self:
        """Create a blocking pipe with inheritable ends, as pipe() does.

        Returns:
            The owned ends.

        Raises:
            OSError: From pipe, such as EMFILE.
        """
        var ends = Array[c_int, 2](fill=-1)
        if external_call["pipe", c_int](ends.unsafe_ptr()) != 0:
            raise OSError.last("pipe")
        return Self(OwnedFd(adopt=ends[0]), OwnedFd(adopt=ends[1]))

    @staticmethod
    def open_self_pipe() raises OSError -> Self:
        """Create a self-pipe: both ends nonblocking and close-on-exec.

        Linux sets both flags atomically with pipe2. Elsewhere pipe() is
        followed by fcntl, and a concurrent fork and exec between the calls
        can inherit the descriptors.

        Returns:
            The owned ends; on failure any created end is closed.

        Raises:
            OSError: From pipe2, pipe or fcntl.
        """
        comptime if CompilationTarget.is_linux():
            var ends = Array[c_int, 2](fill=-1)
            if external_call["pipe2", c_int](ends.unsafe_ptr(), _O_CLOEXEC | O_NONBLOCK) != 0:
                raise OSError.last("pipe2")
            return Self(OwnedFd(adopt=ends[0]), OwnedFd(adopt=ends[1]))
        else:
            var pipe = Self.open()
            set_nonblocking(pipe.read_end.fd)
            set_nonblocking(pipe.write_end.fd)
            set_close_on_exec(pipe.read_end.fd)
            set_close_on_exec(pipe.write_end.fd)
            return pipe^

    def into_read_end(deinit self) -> OwnedFd:
        """Close the write end and keep the read end, which then reaches end of file.

        Returns:
            The read end.
        """
        _ = self.write_end^
        return self.read_end^

    def into_write_end(deinit self) -> OwnedFd:
        """Close the read end and keep the write end, which then fails with EPIPE.

        Returns:
            The write end.
        """
        _ = self.read_end^
        return self.write_end^

    def wake(self) raises OSError -> Bool:
        """Write one byte; a full nonblocking pipe already holds a wake.

        Returns:
            True when a byte was written, False when the pipe was full.

        Raises:
            OSError: Another write error, such as EPIPE or EBADF.
        """
        var byte = Array[UInt8, 1](fill=1)
        try:
            return write(self.write_end.fd, Span(byte)) == 1
        except error:
            if error.is_again():
                return False
            raise error^

    def drain(self) raises OSError -> Int:
        """Read until a nonblocking read end is empty or reaches end of file.

        Returns:
            The number of bytes discarded.

        Raises:
            OSError: A read error other than EAGAIN.
        """
        var buffer = Array[UInt8, 64](fill=0)
        var total = 0
        while True:
            try:
                var count = read(self.read_end.fd, Span(buffer))
                if count == 0:
                    return total
                total += count
            except error:
                if error.is_again():
                    return total
                raise error^


# ===------------------------------------------------------------------=== #
# poll
# ===------------------------------------------------------------------=== #

# Event bits; identical on Linux (verified) and macOS (unverified).
comptime POLLIN: Int16 = 0x001
comptime POLLOUT: Int16 = 0x004
comptime POLLERR: Int16 = 0x008
comptime POLLHUP: Int16 = 0x010
comptime POLLNVAL: Int16 = 0x020


struct PollFd(Copyable, TrivialRegisterPassable):
    """One `struct pollfd`: a descriptor, its interest, and its readiness.

    The layout is int fd at 0, short events at 4, short revents at 6, eight
    bytes in all, on Linux (verified) and macOS (unverified). A negative
    descriptor is ignored by poll and reports no events.
    """

    var fd: c_int
    """The descriptor to wait on."""
    var events: Int16
    """The requested POLLIN and POLLOUT interest."""
    var revents: Int16
    """The events poll reported; POLLERR, POLLHUP and POLLNVAL are always reported."""

    def __init__(out self, fd: c_int, events: Int16):
        """Request interest in events.

        Args:
            fd: The descriptor to wait on.
            events: POLLIN for readability, POLLOUT for writability, or both.
        """
        self.fd = fd
        self.events = events
        self.revents = 0

    def readable(self) -> Bool:
        """Report readability, or a hang-up that makes a read return at once.

        Returns:
            True for POLLIN or POLLHUP.
        """
        return (self.revents & (POLLIN | POLLHUP)) != 0

    def writable(self) -> Bool:
        """Report writability.

        Returns:
            True for POLLOUT.
        """
        return (self.revents & POLLOUT) != 0

    def failed(self) -> Bool:
        """Report an error condition or an invalid descriptor.

        Returns:
            True for POLLERR or POLLNVAL.
        """
        return (self.revents & (POLLERR | POLLNVAL)) != 0

    def ready(self) -> Bool:
        """Report any event.

        Returns:
            True when poll reported anything for this descriptor.
        """
        return self.revents != 0


comptime _nfds_t = Scalar[DType.uint64 if CompilationTarget.is_linux() else DType.uint32]
"""nfds_t: unsigned long on Linux (verified), unsigned int on macOS (unverified)."""


def poll(mut descriptors: List[PollFd], timeout_milliseconds: Int) raises OSError -> Int:
    """Wait until a descriptor is ready or the timeout expires.

    A signal interrupting the wait (EINTR) restarts it with the time remaining
    against `std.time.monotonic()`, the clock of `Instant`, so the call never
    returns early on EINTR.

    Args:
        descriptors: The interest list; each entry's revents is overwritten.
        timeout_milliseconds: Negative waits indefinitely, zero checks without
            waiting; larger values are clamped to the largest C int.

    Returns:
        The number of entries with nonzero revents; zero when the timeout
        expired.

    Raises:
        OSError: From poll, such as EINVAL or ENOMEM.
    """
    comptime assert size_of[PollFd]() == 8, "struct pollfd is eight bytes"
    comptime maximum = Int(Int32.MAX)
    var timeout = min(timeout_milliseconds, maximum)
    var deadline = Int(monotonic()) + timeout * 1_000_000 if timeout > 0 else 0
    while True:
        for i in range(len(descriptors)):
            descriptors[i].revents = 0
        var count = external_call["poll", c_int](descriptors.unsafe_ptr(), _nfds_t(len(descriptors)), c_int(timeout))
        if count >= 0:
            return Int(count)
        var error = OSError.last("poll")
        if error.errno != ErrNo.EINTR:
            raise error^
        if timeout > 0:
            var remaining = deadline - Int(monotonic())
            # Round up so the retry never wakes before the deadline.
            timeout = max(0, (remaining + 999_999) // 1_000_000)


# ===------------------------------------------------------------------=== #
# Time
# ===------------------------------------------------------------------=== #

comptime CLOCK_REALTIME: c_int = 0
comptime CLOCK_MONOTONIC: c_int = c_int(platform_map[T=Int, "CLOCK_MONOTONIC", linux=1, macos=6]())
comptime _nanoseconds_per_second = 1_000_000_000


@fieldwise_init
struct TimeSpec(Copyable, Defaultable, TrivialRegisterPassable):
    """One `struct timespec`: 64-bit seconds at 0 and nanoseconds at 8.

    Sixteen bytes on 64-bit Linux (verified) and macOS (unverified).
    """

    var seconds: Int64
    """Whole seconds (time_t)."""
    var nanoseconds: Int64
    """Nanoseconds within the second, from 0 through 999,999,999 (long)."""

    def __init__(out self):
        """Create a zero time."""
        self.seconds = 0
        self.nanoseconds = 0

    def total_nanoseconds(self) -> Int:
        """Combine into nanoseconds; exact for about 292 years either side of zero.

        Returns:
            The time in nanoseconds.
        """
        return Int(self.seconds) * _nanoseconds_per_second + Int(self.nanoseconds)



def clock_gettime(clock: c_int) raises OSError -> TimeSpec:
    """Read a clock.

    Args:
        clock: CLOCK_MONOTONIC or CLOCK_REALTIME.

    Returns:
        The clock's current time.

    Raises:
        OSError: EINVAL for an unsupported clock.
    """
    comptime assert size_of[TimeSpec]() == 16, "struct timespec is sixteen bytes on 64-bit targets"
    var time = TimeSpec()
    if external_call["clock_gettime", c_int](clock, Pointer(to=time)) != 0:
        raise OSError.last("clock_gettime")
    return time


def _read_clock[clock: c_int]() -> Int:
    try:
        return clock_gettime(clock).total_nanoseconds()
    except error:
        # POSIX requires the clock; failure means a broken platform.
        abort(String("fp._internal.os: ", error))


def realtime_nanoseconds() -> Int:
    """Read CLOCK_REALTIME, which can jump when the system time is set.

    Returns:
        Nanoseconds since the Unix epoch.
    """
    return _read_clock[CLOCK_REALTIME]()


# ===------------------------------------------------------------------=== #
# CPU time
# ===------------------------------------------------------------------=== #

comptime RUSAGE_SELF: c_int = 0
comptime RUSAGE_THREAD: c_int = c_int(_linux_only["RUSAGE_THREAD", linux=1]())
"""Linux only: macOS has no per-thread getrusage."""


@fieldwise_init
struct CpuTime(Copyable, TrivialRegisterPassable):
    """User and system CPU time from getrusage, in nanoseconds."""

    var user_nanoseconds: Int
    """Time spent executing user code."""
    var system_nanoseconds: Int
    """Time spent in the kernel on the caller's behalf."""

    def total_nanoseconds(self) -> Int:
        """Add user and system time.

        Returns:
            The total CPU time.
        """
        return self.user_nanoseconds + self.system_nanoseconds


def _timeval_nanoseconds(usage: Array[Int64, 18], index: Int) -> Int:
    # struct timeval is 16 bytes: time_t tv_sec at 0, then tv_usec at 8, a long
    # on Linux (verified) and a 32-bit suseconds_t followed by padding on macOS
    # (unverified; read as the low half on little-endian targets).
    var microseconds = Int(usage[index + 1])
    comptime if CompilationTarget.is_macos():
        microseconds = Int(Int32(usage[index + 1] & 0xFFFFFFFF))
    return Int(usage[index]) * _nanoseconds_per_second + microseconds * 1000


def getrusage(who: c_int) raises OSError -> CpuTime:
    """Read the CPU time used by the process or the calling thread.

    `struct rusage` is 144 bytes on 64-bit Linux (verified) and macOS
    (unverified): ru_utime at 0 and ru_stime at 16, then fourteen longs that
    this wrapper does not report.

    Args:
        who: RUSAGE_SELF for the whole process, or RUSAGE_THREAD (Linux) for
            the calling thread.

    Returns:
        The user and system CPU time.

    Raises:
        OSError: EINVAL for an unsupported `who`.
    """
    var usage = Array[Int64, 18](fill=0)
    if external_call["getrusage", c_int](who, usage.unsafe_ptr()) != 0:
        raise OSError.last("getrusage")
    return CpuTime(_timeval_nanoseconds(usage, 0), _timeval_nanoseconds(usage, 2))


# ===------------------------------------------------------------------=== #
# Threads
# ===------------------------------------------------------------------=== #

comptime threads_supported = CompilationTarget.is_linux() and is_64bit()
"""Whether OSThread may be used: pthread_t is a 64-bit integer on 64-bit Linux.

macOS's pthread_t is a pointer of the same size; it is unverified and off
until macOS is qualified.
"""

comptime ThreadEntry[S: AnyType] = def(Pointer[S, MutAnyOrigin]) abi("C") thin -> OptionalPointer[NoneType, MutUntrackedOrigin]
"""A C-ABI thread body receiving the shared state; it must not raise."""


struct OSThread[S: Movable & Deinitable](Movable):
    """An owned, joinable OS thread and the state its body receives.

    The owner keeps the state's ArcPointer, so its allocation stays at one
    address, and releases it only after the thread is joined, whether joined
    explicitly or dropped. Mojo has no Send or Sync proof: the caller ensures
    that everything the state holds may be used and destroyed on another
    thread, and synchronizes access shared with the body.

    Parameters:
        S: The state shared by the owner and the thread body.
    """

    var _state: ArcPointer[Self.S]
    var _handle: UInt64

    def __init__(out self, var state: ArcPointer[Self.S], entry: ThreadEntry[Self.S]) raises OSError:
        """Start a thread running `entry` on a pointer to the shared state.

        Args:
            state: The shared state, kept until the thread is joined.
            entry: The thread body, which must not raise.

        Raises:
            OSError: The error number pthread_create returned, such as EAGAIN.
                No thread started, and the state is released.
        """
        comptime assert threads_supported, "OS threads are qualified only on 64-bit Linux"
        self._handle = 0
        # POSIX retains this exact pointer, invisible to Mojo's origin analysis.
        var pointer = Pointer[Self.S, MutAnyOrigin](to=state[])
        var status = external_call["pthread_create", c_int](Pointer(to=self._handle), OptionalPointer[NoneType, ImmUntrackedOrigin](), entry, pointer)
        if status != 0:
            raise OSError("pthread_create", ErrNo(status))
        self._state = state^

    def __deinit__(deinit self):
        _join(self._handle)
        # Unused fields may be destroyed before this destructor's body: make
        # the allocation's final use explicit after joining the thread.
        _ = self._state^

    def state(self) -> ref[self._state] ArcPointer[Self.S]:
        """Borrow the state's owner while the thread may still run.

        Returns:
            The owner; the caller synchronizes access with the body.
        """
        return self._state

    def join(deinit self) -> ArcPointer[Self.S]:
        """Wait for the body to return.

        Returns:
            The state's owner, no longer used by the thread.
        """
        _join(self._handle)
        return self._state^

    def is_current(self) -> Bool:
        """Whether the calling thread is this thread, compared with pthread_equal.

        An owner dropped on its own thread would join itself and deadlock;
        callers that may drop it there check this first and detach instead.

        Returns:
            True when called from the thread's own body.
        """
        return external_call["pthread_equal", c_int](self._handle, external_call["pthread_self", UInt64]()) != 0

    def detach(deinit self) -> ArcPointer[Self.S]:
        """Let the thread finish on its own, without joining it.

        For a thread that must release its own owner, which cannot join
        itself: the blocking pool detaches a worker that drops the pool's last
        handle from inside a call. The OS releases the thread's resources when
        its body returns. The state is released when the returned owner is
        dropped, which the caller may do at once only if the body no longer
        uses the state; nothing waits for the body, so a body that needs its
        state must keep its own reference, as the pool's workers do by taking
        theirs when they start.

        Returns:
            The state's owner, no longer protected by a join.
        """
        var status = external_call["pthread_detach", c_int](self._handle)
        if status != 0:
            abort("fp._internal.os: pthread_detach failed")
        return self._state^


def _join(handle: UInt64):
    # The owner cannot release the state until the thread has stopped. A failed
    # join violates this invariant; continuing would risk use after free.
    var status = external_call["pthread_join", c_int](handle, OptionalPointer[NoneType, MutUntrackedOrigin]())
    if status != 0:
        abort("fp._internal.os: pthread_join failed")
