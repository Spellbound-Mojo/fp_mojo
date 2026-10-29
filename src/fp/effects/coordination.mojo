"""Cancellation-aware shared state and coordination, derived from Ref."""
from std.atomic import Atomic
from std.memory import ArcPointer, MaybeUninit
from std.time import sleep
from std.collections import Deque
from std.os import abort
from std.builtin.rebind import downcast, rebind_var
from .io import IO, IOContext, IOContract, CancellationToken, _run_io, _settle, delay, guarantee, _IODelay, _IOGuarantee
from .protocols import ReaderAction
from .outcomes import Outcome, EffectFailure, _capture
from fp.data import Result, Ok, Err
from fp.algebra import flat_map, BindContract
from fp.callables import UnaryContract, BorrowCallContract, BorrowCallable, OnceUnary, OnceThunk
from fp.callables._receiver import _unary_once_as, _OnceBorrowAvailable
from fp.callables._binding import _BorrowThunk, _BindFirst
from fp.callables._transforms import _Pair
from .capabilities import _Replace
from fp.callables.invoke import _OnceUnaryAvailable
from fp.callables.products import _take_pair
from fp.callables.native import NativeUnary, _Unary, _NativeBorrow, _Borrowing, _RaisingBorrowing
from fp._internal.errors import _ErrorCompatible


@fieldwise_init
struct _Cell[T: Movable & Deinitable](Movable):
    var lock: Atomic[UInt8]
    var slot: Optional[Self.T]


@fieldwise_init
struct _Guard[T: Movable & Deinitable](Movable):
    var cell: ArcPointer[_Cell[Self.T]]
    def __deinit__(deinit self):
        self.cell[].lock.store(0)


def _try_lock[T: Movable & Deinitable](cell: ArcPointer[_Cell[T]]) -> Optional[_Guard[T]]:
    """Attempt the canonical cell guard without blocking a cooperative poll."""
    var expected = UInt8(0)
    if cell[].lock.compare_exchange(expected, UInt8(1)):
        return Optional(_Guard(cell.copy()))
    return None


def _lock[T: Movable & Deinitable, E: Movable & Deinitable](cell: ArcPointer[_Cell[T]], context: IOContext[E]) -> Optional[_Guard[T]]:
    while not context.canceled():
        var guard = _try_lock(cell)
        if guard:
            return guard^
        sleep(0.001)
    return None


@fieldwise_init
struct _RefModify[T: Movable & Deinitable, A: Movable & Deinitable, E: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](ReaderAction, Copyable where conforms_to(F, Copyable)):
    var cell: ArcPointer[_Cell[Self.T]]
    var function: Self.F
    comptime Family = IO[Self.E]
    comptime Env = IOContext[Self.E]
    comptime Value = Self.A
    comptime Out[o: ImmOrigin] = Outcome[Self.A, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        comptime assert Self.F.Arg == Self.T and Self.F.Out == Tuple[Self.T, Self.A] and Self.F.Error == Never
        var locked = _lock(self.cell, context)
        if not locked:
            return None
        var guard = locked.take()
        var old = guard.cell[].slot.take()
        var changed = _unary_once_as[Never](self.function^, rebind_var[Self.F.Arg](old^))
        var state = MaybeUninit[Self.T]()
        var output = MaybeUninit[Self.A]()
        _take_pair(rebind_var[Tuple[Self.T, Self.A]](changed^), state, output)
        var next = state^.unsafe_assume_init()
        var value = output^.unsafe_assume_init()
        guard.cell[].slot = Optional(next^)
        # A canceled result's destructor may access this Ref (e.g. Permit).
        # Unlock before settling and possibly destroying that result.
        _ = guard^
        return _settle(Optional(Result[Self.A, EffectFailure[Self.E]](Ok(value^))), context)


@fieldwise_init
struct _RefInspect[T: Movable & Deinitable, E: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable](ReaderAction, Copyable where conforms_to(F, Copyable)):
    var cell: ArcPointer[_Cell[Self.T]]
    var function: Self.F
    comptime Family = IO[Self.E]
    comptime Env = IOContext[Self.E]
    comptime Value = Self.F.Result
    comptime Out[o: ImmOrigin] = Outcome[Self.Value, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        comptime assert Self.F.Payload == Self.T and _ErrorCompatible[Self.E, Self.F.Failure]
        var locked = _lock(self.cell, context)
        if not locked:
            return None
        var guard = locked.take()
        var result = _capture[Self.E](_BorrowThunk(self.function^, Pointer(to=rebind[Self.F.Payload](guard.cell[].slot.value()))))
        _ = guard^
        return _settle(Optional(result^), context)


@fieldwise_init
struct _Copy[T: Movable & Deinitable](BorrowCallable, Copyable):
    comptime Payload = Self.T
    comptime Result = Self.T
    def invoke(self, ref value: Self.T) -> Self.T:
        comptime C = downcast[Self.T, Copyable & Deinitable]
        return rebind_var[Self.T](rebind[C](value).copy())


@fieldwise_init
struct _Update[F: UnaryContract & Movable & Deinitable](OnceUnary, Copyable where conforms_to(F, Copyable)):
    var function: Self.F
    comptime Arg = Self.F.Arg
    comptime Out = Tuple[Self.F.Arg, NoneType]
    def call_once(deinit self, var value: Self.Arg) -> Self.Out:
        comptime assert Self.F.Error == Never and Self.F.Out == Self.F.Arg
        var next = _unary_once_as[Never](self.function^, value^)
        return (rebind_var[Self.Arg](next^), None)


struct Ref[T: Movable & Deinitable](Copyable):
    """A shared cell with serialized updates, including move-only state.

    Copies share the cell. Operations construct deferred IO recipes. Callbacks
    and state destructors run under the lock and must not reenter the same Ref.
    Lock waits are cancelable; a running native callback is not preempted. No
    fairness is promised. Completed updates survive late cancellation.

    Parameters:
        T: The exact owned state type; callbacks cannot borrow it out of the cell.
    """
    var _cell: ArcPointer[_Cell[Self.T]]

    def __init__(out self, var value: Self.T):
        """Allocate a shared cell containing the transferred initial value."""
        self._cell = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(value^)))

    def modify[E: Movable & Deinitable, A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](self, var function: F) -> _RefModify[Self.T, A, E, F] where F.Arg == Self.T and F.Out == Tuple[Self.T, A] and F.Error == Never and _OnceUnaryAvailable[F]:
        """Atomically consume state and return (new state, result), without raising.

        E selects the IO family; A is the explicit result type. Raising updates
        are rejected because consuming the old state would lose it on failure.

        Parameters:
            E: The selected IO error type.
            A: The owned result type, independent of the cell's borrow.
            F: A once-callable non-raising transformation from T to (T, A).

        Args:
            function: The callback transferred into the deferred operation.

        Returns:
            An IO[E] recipe yielding A after replacing the state.
        """
        return _RefModify[Self.T, A, E, F](self._cell.copy(), function^)

    def modify[P: Movable & Deinitable, R: Movable & Deinitable, //, E: Movable & Deinitable, A: Movable & Deinitable, F: _Unary[P, R]](self, var function: F) -> _RefModify[Self.T, A, E, NativeUnary[P, R, Never, F, False]] where P == Self.T and R == Tuple[P, A]:
        """Adapt a non-raising native state update; spell modify[E, A]."""
        # Infer the native result independently before enforcing the exact tuple;
        # nested tuple inference crashes Mojo 1.2 for otherwise valid callbacks.
        comptime assert NativeUnary[P, R, Never, F, False].Arg == Self.T and NativeUnary[P, R, Never, F, False].Out == Tuple[Self.T, A]
        return self.modify[E, A](NativeUnary[P, R, Never, F, False](function^))

    def inspect[F: BorrowCallContract & Movable & Deinitable, //, E: Movable & Deinitable](self, var function: F) -> _RefInspect[Self.T, E, F] where F.Payload == Self.T and _ErrorCompatible[E, F.Failure] and _OnceBorrowAvailable[F]:
        """Borrow the locked state once; capture exact E/Never errors and unlock.

        Parameters:
            F: A borrowing callable with a result independent of the cell borrow.
            E: The exact compatible IO error type.

        Args:
            function: The observation callback, consumed when the recipe runs.

        Returns:
            An IO[E] observation preserving native errors as EffectFailure.
        """
        return _RefInspect[Self.T, E, F](self._cell.copy(), function^)

    def inspect[P: AnyType, A: Movable & Deinitable, //, E: Movable & Deinitable, F: _Borrowing[P, A]](self, var function: F) -> _RefInspect[Self.T, E, _NativeBorrow[P, A, Never, F, False]] where P == Self.T:
        """Adapt a non-raising native borrowing observation."""
        return self.inspect[E](_NativeBorrow[P, A, Never, F, False](function^))

    def inspect[P: AnyType, A: Movable & Deinitable, X: Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, A, X]](self, var function: F) -> _RefInspect[Self.T, E, _NativeBorrow[P, A, X, F, True]] where P == Self.T and _ErrorCompatible[E, X]:
        """Adapt a native observation with its exact compatible error type."""
        return self.inspect[E](_NativeBorrow[P, A, X, F, True](function^))

    def get[E: Movable & Deinitable](self) -> _RefInspect[Self.T, E, _Copy[Self.T]] where conforms_to(Self.T, Copyable):
        """Defer copying the current value while holding the lock.

        Parameters:
            E: The selected IO error type.

        Returns:
            An IO[E] snapshot; available only when T is Copyable.
        """
        return self.inspect[E](_Copy[Self.T]())

    def update[F: UnaryContract & Movable & Deinitable, //, E: Movable & Deinitable](self, var function: F) -> _RefModify[Self.T, NoneType, E, _Update[F]] where F.Arg == Self.T and F.Out == Self.T and F.Error == Never and _OnceUnaryAvailable[F]:
        """Defer an atomic non-raising transformation, yielding unit.

        Parameters:
            F: A once-callable non-raising transformation from T to T.
            E: The selected IO error type.

        Args:
            function: The owned state transformation.

        Returns:
            An IO[E] recipe yielding NoneType after the update.
        """
        return _RefModify[Self.T, NoneType, E, _Update[F]](self._cell.copy(), _Update(function^))

    def update[P: Movable & Deinitable, R: Movable & Deinitable, //, E: Movable & Deinitable, F: _Unary[P, R]](self, var function: F) -> _RefModify[Self.T, NoneType, E, _Update[NativeUnary[P, R, Never, F, False]]] where P == Self.T and R == Self.T:
        """Adapt a non-raising native state transformation."""
        return self.update[E](NativeUnary[P, R, Never, F, False](function^))

    def set[E: Movable & Deinitable](self, var value: Self.T) -> _RefModify[Self.T, NoneType, E, _Update[_Replace[Self.T]]]:
        """Replace and destroy the previous value when the recipe executes.

        Parameters:
            E: The selected IO error type.

        Args:
            value: The replacement owner, retained until execution or destruction.

        Returns:
            An IO[E] recipe yielding unit after replacement.
        """
        return self.update[E](_Replace(value^))

    def get_and_set[E: Movable & Deinitable](self, var value: Self.T) -> _RefModify[Self.T, Self.T, E, _BindFirst[_Pair[Self.T, Self.T]]]:
        """Replace the state and transfer the previous owner to the caller.

        Parameters:
            E: The selected IO error type.

        Args:
            value: The replacement owner.

        Returns:
            An IO[E] recipe yielding the previous T without copying it.
        """
        return self.modify[E, Self.T](_BindFirst(_Pair[Self.T, Self.T](), value^))


@fieldwise_init
struct _AwaitSome[A: Movable & Deinitable, P: ReaderAction & Copyable](ReaderAction):
    var attempt: Self.P
    comptime E = IOContract[Self.P].Error
    comptime Family = IO[Self.E]
    comptime Env = IOContext[Self.E]
    comptime Value = Self.A
    comptime Out[o: ImmOrigin] = Outcome[Self.A, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        comptime assert Self.P.Value == Optional[Self.A] and IOContract[Self.P].Compatible
        while not context.canceled():
            var outcome = _run_io(self.attempt.copy(), context)
            if not outcome:
                return None
            var result = outcome.take()
            if result.is_err():
                return Optional(Result[Self.A, EffectFailure[Self.E]](Err(result^._take_err())))
            var value = rebind_var[Optional[Self.A]](result^._take_ok())
            if value:
                return _settle(Optional(Result[Self.A, EffectFailure[Self.E]](Ok(value.take()))), context)
            sleep(0.001)
        return None


@fieldwise_init
struct _Complete[T: Copyable & Deinitable](OnceUnary):
    var value: Self.T
    comptime Arg = Optional[Self.T]
    comptime Out = Tuple[Self.Arg, Bool]
    def call_once(deinit self, var current: Self.Arg) -> Self.Out:
        if current:
            return (current^, False)
        return (Optional(self.value^), True)


struct Deferred[T: Copyable & Deinitable](Copyable):
    """A shared, single-assignment value; waiting readers receive copies.

    A successful completion wins once. get waits cooperatively; try_get never
    waits for completion. Use Queue to transfer move-only payloads.

    Parameters:
        T: The copyable completion payload.
    """
    var _state: Ref[Optional[Self.T]]
    def __init__(out self):
        self._state = Ref(Optional[Self.T]())

    def complete[E: Movable & Deinitable](self, var value: Self.T) -> _RefModify[Optional[Self.T], Bool, E, _Complete[Self.T]]:
        """Defer completion; return True only for the winning caller.

        Parameters:
            E: The selected IO error type.

        Args:
            value: The completion owner; destroyed if completion already occurred.

        Returns:
            An IO[E] recipe yielding whether this attempt completed the cell.
        """
        return self._state.modify[E, Bool](_Complete(value^))

    def try_get[E: Movable & Deinitable](self) -> _RefInspect[Optional[Self.T], E, _Copy[Optional[Self.T]]]:
        """Defer a snapshot, absent until completed.

        Parameters:
            E: The selected IO error type.

        Returns:
            An IO[E] recipe yielding Optional[T], copying a completed payload.
        """
        return self._state.get[E]()

    def get[E: Movable & Deinitable](self) -> _AwaitSome[Self.T, _RefInspect[Optional[Self.T], E, _Copy[Optional[Self.T]]]]:
        """Wait for completion, releasing the lock between cancellation checks.

        Parameters:
            E: The selected IO error type.

        Returns:
            An IO[E] recipe yielding a copy of the completed T.
        """
        return _AwaitSome[Self.T, _RefInspect[Optional[Self.T], E, _Copy[Optional[Self.T]]]](self.try_get[E]())


@fieldwise_init
struct _Increment(OnceUnary, Copyable):
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var value: Int) -> Int:
        return value + 1


@fieldwise_init
struct Permit(Movable):
    """One owned semaphore permit, returned automatically when destroyed.

    Acquire through Semaphore. Never copy or manually construct permit owners.
    Dropping a canceled acquisition restores its reserved permit exactly once.
    """
    var _state: Ref[Int]
    var _token: CancellationToken
    def __deinit__(deinit self):
        var context = IOContext[Never](self._token.copy(), True)
        _ = _run_io(self._state.update[Never](_Increment()), context)


@fieldwise_init
struct _Reserve(OnceUnary, Copyable):
    var state: Ref[Int]
    var token: CancellationToken
    comptime Arg = Int
    comptime Out = Tuple[Int, Optional[Permit]]
    def call_once(deinit self, var available: Int) -> Self.Out:
        if available == 0:
            return (available, Optional[Permit]())
        return (available - 1, Optional(Permit(self.state^, self.token^)))


@fieldwise_init
struct _DropPermit(OnceThunk):
    var permit: Permit
    comptime Out = NoneType
    def call_once(deinit self) -> NoneType:
        _ = self.permit^
        return None


@fieldwise_init
struct _WithPermit[P: ReaderAction](OnceUnary):
    var program: Self.P
    comptime Arg = Permit
    comptime E = IOContract[Self.P].Error
    comptime Out = _IOGuarantee[Self.P, _IODelay[Self.E, _DropPermit]]
    def call_once(deinit self, var permit: Permit) -> Self.Out:
        comptime assert IOContract[Self.P].Compatible
        return guarantee(self.program^, delay[Self.E](_DropPermit(permit^)))


struct Semaphore(Copyable):
    """A shared permit count with cancelable acquisition and owned release.

    No fairness ordering is promised. with_permit uses IO's existing guarantee
    scope so all entered success, failure and cancellation paths release.
    """
    var _state: Ref[Int]
    var _token: CancellationToken
    def __init__(out self, permits: Int) raises:
        """Create with a nonnegative number of permits; reject negative input."""
        if permits < 0:
            raise Error("Semaphore requires nonnegative permits")
        self._state = Ref(permits)
        self._token = CancellationToken()

    def available[E: Movable & Deinitable](self) -> _RefInspect[Int, E, _Copy[Int]]:
        """Defer reading the current unreserved permit count.

        Parameters:
            E: The selected IO error type.

        Returns:
            An IO[E] recipe yielding an instantaneous count.
        """
        return self._state.get[E]()

    def acquire[E: Movable & Deinitable](self) -> _AwaitSome[Permit, _RefModify[Int, Optional[Permit], E, _Reserve]]:
        """Wait for and return a single owned permit; dropping it releases.

        Parameters:
            E: The selected IO error type.

        Returns:
            An IO[E] recipe yielding one move-only Permit.
        """
        return _AwaitSome[Permit, _RefModify[Int, Optional[Permit], E, _Reserve]](self._state.modify[E, Optional[Permit]](_Reserve(self._state.copy(), self._token.copy())))

    def with_permit[P: ReaderAction](self, var program: P) -> BindContract[IO[IOContract[P].Error], _AwaitSome[Permit, _RefModify[Int, Optional[Permit], IOContract[P].Error, _Reserve]], _WithPermit[P]].Out where IOContract[P].Compatible:
        """Defer acquiring a permit, running the program, and releasing it.

        Parameters:
            P: A compatible concrete IO program.

        Args:
            program: The owned body to enter after acquiring a permit.

        Returns:
            An IO recipe preserving the body's value and error types. The permit
            is returned on success, failure, cancellation, or an unopened drop.
        """
        return flat_map[IO[IOContract[P].Error]](_WithPermit(program^), self.acquire[IOContract[P].Error]())


@fieldwise_init
struct _TryTake[T: Movable & Deinitable](OnceUnary, Copyable):
    comptime Arg = Deque[Self.T]
    comptime Out = Tuple[Self.Arg, Optional[Self.T]]
    def call_once(deinit self, var values: Self.Arg) -> Self.Out:
        var value = _try_pop(values)
        return (values^, value^)


def _try_pop[T: Movable & Deinitable](mut values: Deque[T]) -> Optional[T]:
    if len(values) == 0:
        return None
    try:
        return Optional(values.popleft())
    except:
        abort("fp.effects: nonempty queue failed to remove its head")


@fieldwise_init
struct _TryOffer[T: Movable & Deinitable](OnceUnary):
    var value: Self.T
    var capacity: Int
    comptime Arg = Deque[Self.T]
    comptime Out = Tuple[Self.Arg, Optional[Self.T]]
    def call_once(deinit self, var values: Self.Arg) -> Self.Out:
        if len(values) == self.capacity:
            return (values^, Optional(self.value^))
        values.append(self.value^)
        return (values^, Optional[Self.T]())


@fieldwise_init
struct _Size[T: Movable & Deinitable](BorrowCallable, Copyable):
    comptime Payload = Deque[Self.T]
    comptime Result = Int
    def invoke(self, ref value: Self.Payload) -> Int:
        return len(value)


@fieldwise_init
struct _Offer[T: Movable & Deinitable, E: Movable & Deinitable](ReaderAction):
    var state: Ref[Deque[Self.T]]
    var capacity: Int
    var value: Self.T
    comptime Family = IO[Self.E]
    comptime Env = IOContext[Self.E]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Self.E]
    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        # Unlike read-only polling, offering must carry a unique rejected owner
        # into the next attempt. The same Ref.modify owns every queue mutation.
        var pending = Optional(self.value^)
        while not context.canceled():
            var outcome = _run_io(self.state.modify[Self.E, Optional[Self.T]](_TryOffer(pending.take(), self.capacity)), context)
            if not outcome:
                return None
            var result = outcome.take()
            if result.is_err():
                return Optional(Result[NoneType, EffectFailure[Self.E]](Err(result^._take_err())))
            pending = result^._take_ok()
            if not pending:
                var unit: NoneType = None
                return _settle(Optional(Result[NoneType, EffectFailure[Self.E]](Ok(unit))), context)
            sleep(0.001)
        return None


struct Queue[T: Movable & Deinitable](Copyable):
    """A bounded shared FIFO, transferring payloads without requiring copies.

    offer/take wait cooperatively; try_offer/try_take make one locked attempt.
    A completed enqueue or dequeue survives late cancellation; an unobserved
    removed owner is destroyed. No rollback or waiter fairness is promised.

    Parameters:
        T: The exact owned payload, including move-only values.
    """
    var _state: Ref[Deque[Self.T]]
    var _capacity: Int
    def __init__(out self, capacity: Int) raises:
        """Create an empty queue with positive capacity; reject other inputs."""
        if capacity <= 0:
            raise Error("Queue requires positive capacity")
        self._state = Ref(Deque[Self.T]())
        self._capacity = capacity

    def size[E: Movable & Deinitable](self) -> _RefInspect[Deque[Self.T], E, _Size[Self.T]]:
        """Defer reading the number of buffered values.

        Parameters:
            E: The selected IO error type.

        Returns:
            An IO[E] recipe yielding an instantaneous queue size.
        """
        return self._state.inspect[E](_Size[Self.T]())

    def try_offer[E: Movable & Deinitable](self, var value: Self.T) -> _RefModify[Deque[Self.T], Optional[Self.T], E, _TryOffer[Self.T]]:
        """Attempt enqueue once; return the original owner if the queue is full.

        Parameters:
            E: The selected IO error type.

        Args:
            value: The owner to enqueue.

        Returns:
            An IO[E] recipe yielding None when accepted or Some(T) when full.
        """
        return self._state.modify[E, Optional[Self.T]](_TryOffer(value^, self._capacity))

    def offer[E: Movable & Deinitable](self, var value: Self.T) -> _Offer[Self.T, E]:
        """Wait for space and enqueue once, retaining the owner while waiting.

        Parameters:
            E: The selected IO error type.

        Args:
            value: The owner to enqueue; destroyed if canceled before acceptance.

        Returns:
            An IO[E] recipe yielding unit after the enqueue.
        """
        return _Offer[Self.T, E](self._state.copy(), self._capacity, value^)

    def try_take[E: Movable & Deinitable](self) -> _RefModify[Deque[Self.T], Optional[Self.T], E, _TryTake[Self.T]]:
        """Attempt dequeue once; return absence if empty.

        Parameters:
            E: The selected IO error type.

        Returns:
            An IO[E] recipe yielding Optional[T] without copying the payload.
        """
        return self._state.modify[E, Optional[Self.T]](_TryTake[Self.T]())

    def take[E: Movable & Deinitable](self) -> _AwaitSome[Self.T, _RefModify[Deque[Self.T], Optional[Self.T], E, _TryTake[Self.T]]]:
        """Wait for and transfer the oldest buffered value.

        Parameters:
            E: The selected IO error type.

        Returns:
            An IO[E] recipe yielding the next owned T.
        """
        return _AwaitSome[Self.T, _RefModify[Deque[Self.T], Optional[Self.T], E, _TryTake[Self.T]]](self.try_take[E]())
