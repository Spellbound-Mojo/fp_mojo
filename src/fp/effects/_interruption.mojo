"""The interruption handle an interruptible function receives.

It lives below both families: the async blocking pool and SyncIO's inline
provider build it from a cancellation token, so the request it reports is the
token's, and it stays visible once made.
"""
from fp.callables.protocols import BorrowCallContract, OnceThunk
from fp.callables._receiver import _borrow_once_as
from ._io_core import CancellationToken


struct Interruption:
    """A cancellation request visible to an interruptible function.

    `IO.interruptible` and `SyncIO`'s inline `interruptible` lend it to the
    function for the duration of the call. It is neither copyable nor movable,
    and the function receives it borrowed, so it cannot outlive the call.

    A request stays visible once made, so a function that checks repeatedly
    sees every later check report it; there is no separate
    `interruptibleMany`. No POSIX signal is sent: a function blocked in an
    operating-system call that does not go through this handle is not woken,
    and cancellation waits for it to return.
    """
    var _token: CancellationToken

    def __init__(out self, *, _token: CancellationToken):
        self._token = _token.copy()

    def requested(self) -> Bool:
        """Whether cancellation of the interruptible call was requested.

        Safe from the function's thread while another thread requests it: the
        request is an atomic flag, and writes made before the request are
        visible once this returns True.

        Returns:
            True once the call's cancellation was requested; it stays True.
        """
        return self._token.requested()


@fieldwise_init
struct _LendInterruption[F: BorrowCallContract & Movable & Deinitable](OnceThunk):
    """Call an interruptible function with a handle that lives only for the call."""
    var function: Self.F
    var token: CancellationToken
    comptime Out = Self.F.Result
    comptime Error = Self.F.Failure

    def call_once(deinit self) raises Self.Error -> Self.Out:
        comptime assert Self.F.Payload == Interruption
        var handle = Interruption(_token=self.token)
        return _borrow_once_as[Self.Error](rebind[Self.F.Payload](handle), self.function^)
