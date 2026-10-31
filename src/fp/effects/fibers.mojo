"""Typed, owned OS-thread fibers for Linux; cancellation remains cooperative."""
from std.atomic import Atomic
from std.memory import ArcPointer
from std.time import sleep
from fp._internal.os import OSThread, threads_supported
from .io import IO, IOContext, IOContract, CancellationToken, _run_io, _settle
from .outcomes import Outcome
from .protocols import ReaderAction


@fieldwise_init
struct _FiberState[P: ReaderAction](Movable):
    var program: Optional[Self.P]
    var result: Optional[IOContract[Self.P].Out]
    var done: Atomic[UInt8]
    var context: IOContext[IOContract[Self.P].Error]


def _worker[P: ReaderAction](state: Pointer[_FiberState[P], MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    comptime assert IOContract[P].Compatible
    var program = state[].program.take()
    var context = state[].context.copy()
    var result = _run_io(program^, context)
    state[].result = Optional(result^)
    state[].done.store(1)
    return None


@fieldwise_init
struct Fiber[P: ReaderAction](Movable):
    """A single owned worker, joined before its captured owners can be destroyed.

    Construct with unsafe_start. Dropping requests cancellation and waits for
    the worker and its finalizers; this can block indefinitely in native code
    which does not cooperate. Join explicitly to observe errors. The concrete
    program type preserves captured origins and move-only values.

    Parameters:
        P: A compatible IO recipe and its captured owners.
    """
    var _thread: OSThread[_FiberState[Self.P]]
    var _token: CancellationToken

    def __deinit__(deinit self):
        self._token.cancel()
        # The thread owner joins before it releases the state.
        _ = self._thread^.join()

    def request_cancel(self):
        """Request cancellation without waiting for the worker to stop."""
        self._token.cancel()

    def done(self) -> Bool:
        """Check whether execution and all entered finalizers have completed.

        Returns:
            True when the worker has published its final outcome.
        """
        return self._thread.state()[].done.load() != 0

    def join(deinit self) -> IOContract[Self.P].Out:
        """Wait synchronously and consume the worker's exact outcome.

        Returns:
            Its success, accumulated exact errors, or cancellation.
        """
        var state = self._thread^.join()
        return state[].result.take()

    def cancel(deinit self) -> IOContract[Self.P].Out:
        """Request cancellation, wait for finalization, and return its outcome.

        Returns:
            The joined outcome, preserving any body and finalizer errors.
        """
        self.request_cancel()
        return self^.join()

    def join_io(deinit self) -> _JoinFiber[Self.P]:
        """Defer joining; parent cancellation cancels and waits for the child.

        Dropping this unopened recipe still drops and joins the owned fiber.
        Child errors survive parent cancellation, with the canceled flag set.

        Returns:
            An owned IO recipe in the child's error family.
        """
        return _JoinFiber(self^)


@fieldwise_init
struct _JoinFiber[P: ReaderAction](ReaderAction):
    var fiber: Fiber[Self.P]
    comptime E = IOContract[Self.P].Error
    comptime Family = IO[Self.E]
    comptime Env = IOContext[Self.E]
    comptime Value = Self.P.Value
    comptime Out[o: ImmOrigin] = Outcome[Self.Value, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        while not self.fiber.done():
            if env.canceled():
                self.fiber.request_cancel()
            sleep(0.001)
        return _settle(self.fiber^.join(), env)


def unsafe_start[P: ReaderAction](var program: P) raises -> Fiber[P] where IOContract[P].Compatible:
    """Start one 64-bit Linux OS thread immediately, transferring an IO recipe to it.

    The caller must ensure that every captured value, its callbacks, and its
    destructors may run on a different thread, and that shared mutations are
    synchronized. Mojo has no Send/Sync proof; origin checking alone does not
    establish this safety. This is not a lightweight fiber scheduler.

    Parameters:
        P: The complete concrete IO program type, without erased origins.

    Args:
        program: The owned program, consumed once by the worker on success.

    Returns:
        A move-only handle which joins before releasing the program's state.

    Raises:
        Error if the platform is unsupported or pthread_create fails. Failure
        destroys the unopened program without running its finalizers.
    """
    comptime if threads_supported:
        var token = CancellationToken()
        var state = ArcPointer(_FiberState[P](Optional(program^), Optional[IOContract[P].Out](), Atomic(UInt8(0)), IOContext[IOContract[P].Error](token.copy(), False)))
        # Only the worker touches program/result before join; done and
        # cancellation are atomic. The thread owner keeps the state until join.
        try:
            return Fiber[P](OSThread(state^, _worker[P]), token^)
        except:
            raise Error("fp.effects: pthread_create failed")
    else:
        raise Error("fp.effects: fibers currently require 64-bit Linux")
