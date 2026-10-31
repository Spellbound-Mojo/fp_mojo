"""The interruption handle an interruptible function receives.

It lives below both families: the async blocking pool and SyncIO's inline
provider build it from a cancellation token, so the request it reports is the
token's, and it stays visible once made.
"""
from fp.callables.protocols import BorrowCallContract, OnceThunk
from fp.callables._receiver import _borrow_once_as
from std.os import abort
from std.time import monotonic
from fp._internal.time import Duration
from ._io_core import CancellationToken
from std.ffi import c_int
from fp._internal.os import OSError
from fp._internal.waking import Signal
from ._async.polling import _Poller, _Registration, READ_INTEREST, WRITE_INTEREST


struct Interruption:
    """A cancellation request visible to an interruptible function.

    `IO.interruptible` and `SyncIO`'s inline `interruptible` lend it to the
    function for the duration of the call. It is neither copyable nor movable,
    and the function receives it borrowed, so it cannot outlive the call.

    A request stays visible once made, so a function that checks repeatedly
    sees every later check report it; there is no separate
    `interruptibleMany`. On a blocking-pool worker, waits made through the
    handle wake at once when the request arrives. No POSIX signal is sent: a
    function blocked in an operating-system call that does not go through this
    handle is not woken, and cancellation waits for it to return.
    """
    var _token: CancellationToken
    # The worker's poller, which the request interrupts; None inline in SyncIO.
    var _poller: Optional[Pointer[_Poller, MutUntrackedOrigin]]

    def __init__(out self, *, _token: CancellationToken, _poller: Optional[Pointer[_Poller, MutUntrackedOrigin]] = None):
        self._token = _token.copy()
        self._poller = _poller

    def requested(self) -> Bool:
        """Whether cancellation of the interruptible call was requested.

        Safe from the function's thread while another thread requests it: the
        request is an atomic flag, and writes made before the request are
        visible once this returns True.

        Returns:
            True once the call's cancellation was requested; it stays True.
        """
        return self._token.requested()

    def sleep(self, duration: Duration) -> Bool:
        """Wait for a duration, waking early when cancellation is requested.

        On a blocking-pool worker the wait parks in the worker's poller, which
        the request interrupts. Inline in SyncIO the wait parks in a poller of
        its own that nothing interrupts: a request made during the wait is
        observed only when it ends.

        Args:
            duration: How long to wait, measured from the call.

        Returns:
            True when the duration elapsed, False when cancellation was
            requested first.
        """
        try:
            return self._wait(None, 0, Optional(duration.copy()))
        except:
            abort("fp.effects: Interruption.sleep could not poll")

    def await_readable(self, fd: RawFileDescriptor, timeout: Optional[Duration] = None) raises OSError -> Bool:
        """Wait until a descriptor is readable, waking early when cancellation is requested.

        The caller owns the descriptor and keeps it open during the wait. Hang-up
        and error conditions count as ready: the caller finds them by reading.

        Args:
            fd: The descriptor.
            timeout: How long to wait at most; None waits until ready or interrupted.

        Returns:
            True when the descriptor is ready; False when cancellation was
            requested or the timeout expired, told apart with `requested()`.

        Raises:
            OSError: From poll.
        """
        return self._wait(Optional(c_int(fd.value)), READ_INTEREST, timeout)

    def await_writable(self, fd: RawFileDescriptor, timeout: Optional[Duration] = None) raises OSError -> Bool:
        """Wait until a descriptor is writable, waking early when cancellation is requested.

        The caller owns the descriptor and keeps it open during the wait. Hang-up
        and error conditions count as ready: the caller finds them by writing.

        Args:
            fd: The descriptor.
            timeout: How long to wait at most; None waits until ready or interrupted.

        Returns:
            True when the descriptor is ready; False when cancellation was
            requested or the timeout expired, told apart with `requested()`.

        Raises:
            OSError: From poll.
        """
        return self._wait(Optional(c_int(fd.value)), WRITE_INTEREST, timeout)

    def _wait(self, fd: Optional[c_int], interest: Int16, timeout: Optional[Duration]) raises OSError -> Bool:
        """The one wait loop: park until ready, requested, or the deadline.

        A worker's poller belongs to the worker running this call, so the
        registration is made and removed on the owner thread. Inline, a fresh
        poller serves the one call.
        """
        if self.requested():
            return False
        var fresh = Optional[_Poller]()
        if not self._poller:
            fresh = Optional(_Poller())
        var poller = self._poller.value() if self._poller else Pointer(to=fresh.value()).unsafe_origin_cast[MutUntrackedOrigin]()
        var deadline = Int(monotonic()) + timeout.value().to_nanoseconds() if timeout else 0
        var signal = Signal()
        var registration = Optional[_Registration]()
        if fd:
            registration = poller[].register(fd.value(), interest, signal)
        var ready = False
        var failure = Optional[OSError]()
        while True:
            if registration and poller[].readiness(registration.value()).ready():
                ready = True
                break
            if self.requested():
                break
            var wait = Optional[Duration]()
            if timeout:
                var remaining = deadline - Int(monotonic())
                if remaining <= 0:
                    # A sleep's whole duration elapsing is its success.
                    ready = not fd
                    break
                var slice = Duration()
                slice._nanoseconds = remaining
                wait = Optional(slice^)
            try:
                var result = poller[].poll(wait)
                if result.closed:
                    break
            except error:
                failure = Optional(error^)
                break
        if registration:
            _ = poller[].deregister(registration.value())
        # The fresh poller outlives every use through `poller`.
        _ = fresh^
        if failure:
            raise failure.take()
        return ready


@fieldwise_init
struct _LendInterruption[F: BorrowCallContract & Movable & Deinitable](OnceThunk):
    """Call an interruptible function with a handle that lives only for the call."""
    var function: Self.F
    var token: CancellationToken
    var poller: Optional[Pointer[_Poller, MutUntrackedOrigin]]
    comptime Out = Self.F.Result
    comptime Error = Self.F.Failure

    def call_once(deinit self) raises Self.Error -> Self.Out:
        comptime assert Self.F.Payload == Interruption
        var handle = Interruption(_token=self.token, _poller=self.poller)
        return _borrow_once_as[Self.Error](rebind[Self.F.Payload](handle), self.function^)
