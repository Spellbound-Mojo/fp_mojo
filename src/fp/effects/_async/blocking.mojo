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
from fp.callables.protocols import ThunkContract, BorrowCallContract, OnceThunk, OnceUnary
from fp.callables._receiver import _thunk_once_as, _borrow_once_as
from fp._internal.cells import _Cell, _lock_cell
from fp._internal.erased import _Erased
from fp._internal.errors import _ErrorCompatible
from fp.data import Result, Ok
from fp.effects import IOContext, EffectFailure, CancellationToken
from fp.effects.outcomes import _capture
from fp.effects._interruption import Interruption
from .callbacks import Completion
from .kernel import Machine, Step
from .scheduling.blocking_pool import _RootBlocking


# ===------------------------------------------------------------------=== #
# Calls
# ===------------------------------------------------------------------=== #


comptime _CallValue[R: Movable & Deinitable] = NoneType if R == type_of(None) else R
"""A function with no return value produces the unit value, as IO.delay's does."""


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


def _run_blocking[F: ThunkContract & Movable & Deinitable, E: Movable & Deinitable](var body: _Erased):
    """Run a blocking call on a worker; a rejected outcome is destroyed here."""
    comptime assert _ErrorCompatible[E, F.Error]
    var call = body^.take[_BlockingCall[F, E]]()
    var outcome = Optional(_capture[E](_UnitThunk[F](call.function^)))
    _ = call.completion.complete(outcome^)


struct _ReturnState[E: Movable & Deinitable](Movable):
    """Whether an interruptible function returned, and who waits for it."""
    var returned: Bool
    var waiter: Optional[Completion[NoneType, E]]

    def __init__(out self):
        self.returned = False
        self.waiter = None


struct _Interrupt[E: Movable & Deinitable](Copyable):
    """One interruptible call's request and return, shared by its fiber and its worker."""
    var token: CancellationToken
    var state: ArcPointer[_Cell[_ReturnState[Self.E]]]

    def __init__(out self):
        self.token = CancellationToken()
        self.state = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(_ReturnState[Self.E]())))

    def returned(self):
        """The function returned: release the fiber's withdrawal if it waits."""
        var guard = _lock_cell(self.state[])
        guard.cell[].slot.value().returned = True
        var waiter = guard.cell[].slot.value().waiter^
        guard.cell[].slot.value().waiter = None
        _ = guard^
        if waiter:
            var unit: NoneType = None
            _ = waiter.value().complete(Optional(Result[NoneType, EffectFailure[Self.E]](Ok(unit))))

    def await_return(self, var completion: Completion[NoneType, Self.E]):
        """Request interruption, then complete `completion` once the function returned."""
        self.token.cancel()
        var guard = _lock_cell(self.state[])
        var done = guard.cell[].slot.value().returned
        if not done:
            guard.cell[].slot.value().waiter = Optional(completion.copy())
        _ = guard^
        if done:
            var unit: NoneType = None
            _ = completion.complete(Optional(Result[NoneType, EffectFailure[Self.E]](Ok(unit))))


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


@fieldwise_init
struct _InterruptibleCall[F: BorrowCallContract & Movable & Deinitable, E: Movable & Deinitable](Movable):
    """An interruptible function, its completion, and its interruption state."""
    var function: Self.F
    var completion: Completion[Self.F.Result, Self.E]
    var interrupt: _Interrupt[Self.E]


def _run_interruptible[F: BorrowCallContract & Movable & Deinitable, E: Movable & Deinitable](var body: _Erased):
    """Run an interruptible call on a worker, then report its return."""
    comptime assert _ErrorCompatible[E, F.Failure]
    var call = body^.take[_InterruptibleCall[F, E]]()
    var interrupt = call.interrupt.copy()
    var outcome = Optional(_capture[E](_LendInterruption[F](call.function^, interrupt.token)))
    _ = call.completion.complete(outcome^)
    interrupt.returned()


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
        return Step[_RootBlocking, Self.E].ready(Optional(Result[_RootBlocking, EffectFailure[Self.E]](Ok(_root_blocking(context)))))
