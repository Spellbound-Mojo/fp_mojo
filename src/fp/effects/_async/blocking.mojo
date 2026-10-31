"""IO.blocking and IO.interruptible over the blocking pool, through Completion.

A call is an `IO.async` registration whose register function queues the call
on the running root's pool (`scheduling.blocking_pool`); the worker runs the
function and completes the registration's `Completion` with its outcome, so
only `Completion`'s public behavior crosses threads:

- `blocking` registers inside a masked region, so cancellation and timeouts
  wait for the function to return, as Cats Effect's `blocking` does.
- `interruptible` registers unmasked. On cancellation the registration closes
  canceled, and its withdrawal, which runs masked after every entered
  registration, requests interruption through the call's token and waits for
  the worker to report that the function returned. Cancellation therefore
  completes after the function returns, and its late outcome is rejected and
  destroyed on the worker.

The function, its result and its error move to the worker and back: Mojo has
no Send or Sync proof, so the caller asserts they may move to, be used on, and
be destroyed on another thread.
"""
from std.atomic import Atomic
from std.builtin.rebind import rebind_var
from std.memory import ArcPointer
from std.os import abort
from fp.callables.protocols import ThunkContract, BorrowCallContract, OnceThunk, OnceUnary
from fp.callables._receiver import _thunk_once_as
from fp._internal.cells import _Cell, _lock_cell
from fp._internal.erased import _Erased
from fp._internal.errors import _ErrorCompatible
from fp.data import Result, Ok
from fp.effects import IOContext, EffectFailure, CancellationToken
from fp.effects.outcomes import _capture
from fp.effects._interruption import _LendInterruption
from .callbacks import Completion
from .kernel import Machine, Step
from .scheduling.blocking_pool import _RootBlocking, _root_blocking, _WorkerContext
from .polling import _Interrupter


# ===------------------------------------------------------------------=== #
# Calls
# ===------------------------------------------------------------------=== #


comptime _CallValue[R: Movable & Deinitable] = NoneType if R == type_of(None) else R
"""A function with no return value produces the unit value; IO.delay shares it."""


@fieldwise_init
struct _UnitThunk[F: ThunkContract & Movable & Deinitable](OnceThunk):
    """Call a thunk and produce its value, or the unit value for no value."""
    var function: Self.F
    comptime Out = _CallValue[Self.F.Out]
    comptime Error = Self.F.Error

    def call_once(deinit self) raises Self.Error -> Self.Out:
        comptime if Self.F.Out == type_of(None):
            _ = _thunk_once_as[Self.Error](self.function^)
            var unit: NoneType = None
            return rebind_var[Self.Out](unit)
        else:
            return rebind_var[Self.Out](_thunk_once_as[Self.Error](self.function^))


@fieldwise_init
struct _BlockingCall[F: ThunkContract & Movable & Deinitable, E: Movable & Deinitable](Movable):
    """A blocking function and the completion its outcome goes to."""
    var function: Self.F
    var completion: Completion[_CallValue[Self.F.Out], Self.E]

    def run(deinit self):
        comptime assert _ErrorCompatible[Self.E, Self.F.Error]
        var outcome = Optional(_capture[Self.E](_UnitThunk[Self.F](self.function^)))
        _ = self.completion.complete(outcome^)


def _run_blocking[F: ThunkContract & Movable & Deinitable, E: Movable & Deinitable](var body: _Erased, worker: _WorkerContext):
    """Run a blocking call on a worker; a rejected outcome is destroyed here."""
    comptime assert _ErrorCompatible[E, F.Error]
    body^.take[_BlockingCall[F, E]]().run()


struct _ReturnState[E: Movable & Deinitable](Movable):
    """Whether an interruptible function returned, and who waits for it."""
    var returned: Bool
    var waiter: Optional[Completion[NoneType, Self.E]]
    # The running worker's interrupter, published while the function runs.
    var worker: Optional[_Interrupter]

    def __init__(out self):
        self.returned = False
        self.waiter = None
        self.worker = None


struct _Interrupt[E: Movable & Deinitable](Copyable):
    """One interruptible call's request and return, shared by its fiber and its worker."""
    var token: CancellationToken
    var state: ArcPointer[_Cell[_ReturnState[Self.E]]]

    def __init__(out self):
        self.token = CancellationToken()
        self.state = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(_ReturnState[Self.E]())))

    def started(self, worker: _Interrupter):
        """Publish the worker before the function runs, so a request can wake its waits.

        Under the state's lock, as `await_return`'s read: either the
        withdrawal sees the worker and interrupts it, or the token's request,
        made before the withdrawal's lock, is visible to the function's next
        `requested()` check.
        """
        var guard = _lock_cell(self.state[])
        guard.cell[].slot.value().worker = Optional(worker.copy())
        _ = guard^

    def returned(self):
        """The function returned: release the fiber's withdrawal if it waits."""
        var guard = _lock_cell(self.state[])
        guard.cell[].slot.value().returned = True
        guard.cell[].slot.value().worker = None
        var waiter = guard.cell[].slot.value().waiter.take() if guard.cell[].slot.value().waiter else Optional[Completion[NoneType, Self.E]]()
        _ = guard^
        if waiter:
            var unit: NoneType = None
            _ = waiter.value().complete(Optional(Result[NoneType, EffectFailure[Self.E]](Ok(unit))))

    def await_return(self, var completion: Completion[NoneType, Self.E]):
        """Request interruption, then complete `completion` once the function returned."""
        self.token.cancel()
        var guard = _lock_cell(self.state[])
        var done = guard.cell[].slot.value().returned
        var worker = guard.cell[].slot.value().worker.copy()
        if not done:
            guard.cell[].slot.value().waiter = Optional(completion.copy())
        _ = guard^
        if worker:
            # Wakes a wait made through the handle; otherwise a spurious wake.
            worker.value().interrupt()
        if done:
            var unit: NoneType = None
            _ = completion.complete(Optional(Result[NoneType, EffectFailure[Self.E]](Ok(unit))))


@fieldwise_init
struct _InterruptibleCall[F: BorrowCallContract & Movable & Deinitable, E: Movable & Deinitable](Movable):
    """An interruptible function, its completion, and its interruption state."""
    var function: Self.F
    var completion: Completion[Self.F.Result, Self.E]
    var interrupt: _Interrupt[Self.E]

    def run(deinit self, worker: _WorkerContext):
        comptime assert _ErrorCompatible[Self.E, Self.F.Failure]
        self.interrupt.started(worker.interrupter)
        var outcome = Optional(_capture[Self.E](_LendInterruption[Self.F](self.function^, self.interrupt.token.copy(), Optional(worker.poller))))
        _ = self.completion.complete(outcome^)
        self.interrupt.returned()


def _run_interruptible[F: BorrowCallContract & Movable & Deinitable, E: Movable & Deinitable](var body: _Erased, worker: _WorkerContext):
    """Run an interruptible call on a worker, then report its return."""
    comptime assert _ErrorCompatible[E, F.Failure]
    body^.take[_InterruptibleCall[F, E]]().run(worker)


@fieldwise_init
struct _SubmitBlocking[F: ThunkContract & Movable & Deinitable, E: Movable & Deinitable](OnceUnary):
    """The registration of IO.blocking: queue the call on the root's pool."""
    var function: Self.F
    var root: _RootBlocking
    comptime Arg = Completion[_CallValue[Self.F.Out], Self.E]
    comptime Out = NoneType

    def call_once(deinit self, var completion: Self.Arg) -> NoneType:
        self.root.submit(_Erased(_BlockingCall[Self.F, Self.E](self.function^, completion^)), _run_blocking[Self.F, Self.E])
        return None


@fieldwise_init
struct _SubmitInterruptible[F: BorrowCallContract & Movable & Deinitable, E: Movable & Deinitable](OnceUnary):
    """The registration of IO.interruptible: queue the call on the root's pool."""
    var function: Self.F
    var root: _RootBlocking
    var interrupt: _Interrupt[Self.E]
    comptime Arg = Completion[Self.F.Result, Self.E]
    comptime Out = NoneType

    def call_once(deinit self, var completion: Self.Arg) -> NoneType:
        self.root.submit(_Erased(_InterruptibleCall[Self.F, Self.E](self.function^, completion^, self.interrupt^)), _run_interruptible[Self.F, Self.E])
        return None


@fieldwise_init
struct _AwaitReturn[E: Movable & Deinitable](OnceUnary):
    """The withdrawal of IO.interruptible: request interruption, then wait for the return."""
    var interrupt: _Interrupt[Self.E]
    comptime Arg = Completion[NoneType, Self.E]
    comptime Out = NoneType

    def call_once(deinit self, var completion: Self.Arg) -> NoneType:
        self.interrupt.await_return(completion^)
        return None


struct _CurrentBlocking[E: Movable & Deinitable](Machine, Defaultable):
    """Read the running root's blocking access once."""
    comptime Value = _RootBlocking
    comptime Error = Self.E

    def __init__(out self):
        pass

    def poll(mut self, context: IOContext[Self.E]) -> Step[_RootBlocking, Self.E]:
        if not context._runtime:
            abort("fp.effects: blocking calls run only under a driver")
        var root = _root_blocking(context._runtime.value().scheduler())
        return Step[_RootBlocking, Self.E].ready(Optional(Result[_RootBlocking, EffectFailure[Self.E]](Ok(root^))))
