"""The interruption handle an interruptible function receives.

It lives below both families: the async blocking pool and SyncIO's inline
provider build it from a cancellation token, so the request it reports is the
token's, and it stays visible once made.
"""
from fp.callables.protocols import BorrowCallContract, OnceThunk
from fp.callables._receiver import _borrow_once_as
from std.os import abort
from std.time import monotonic, sleep as _sleep
from fp._internal.time import Duration
from ._io_core import CancellationToken
from ._async.polling import _Poller


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
        the request interrupts. Inline in SyncIO there is no other thread to
        wake it: the wait blocks for the whole duration, and only a request
        made before it starts ends it early.

        Args:
            duration: How long to wait, measured from the call.

        Returns:
            True when the duration elapsed, False when cancellation was
            requested before it did.
        """
        if self.requested():
            return False
        var deadline = Int(monotonic()) + duration.to_nanoseconds()
        if not self._poller:
            _sleep(Float64(duration.to_nanoseconds()) / 1e9)
            return True
        while True:
            if self.requested():
                return False
            var remaining = deadline - Int(monotonic())
            if remaining <= 0:
                return True
            try:
                _ = self._poller.value()[].poll(Optional(Duration.nanoseconds(remaining)))
            except:
                abort("fp.effects: Interruption.sleep could not poll")


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
