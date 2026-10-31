"""Fiber records, ownership scopes and fiber tasks: the scheduling half of `IO.start`.

`io.start()` queues the child on the starting run loop, which admits it as a
task of the root's executor (`executor.mojo`) when its run segment ends. Each
fiber has its own wake registry, whose hook schedules its task, so a fiber runs
only when something in it is ready, and nested fibers cost no native stack. The
IO surface, `Fiber` and `start`, lives in `engine.mojo` and builds on this module.

A handle and its child share a record typed only by E: the child's token, a
completion signal, and the settled outcome, whose success holds T erased. A run
loop's started fibers belong to its ownership scope, which counts its live
children atomically: when a fiber's program is terminal, its task cancels the
children of its scope and completes only after the count reaches zero, so fibers
never outlive their owner. An IO polled as a leaf drains the scope of its own
run loop the same way before completing.
"""
from std.atomic import Atomic, Ordering
from std.builtin.rebind import downcast
from std.memory import ArcPointer
from std.os import abort
from fp.callables import OnceUnary
from fp.data import Result, Ok
from fp._internal.erased import _Erased
from fp._internal.cells import _acquire_lock, _release_lock
from fp._internal.waking import _Event as Signal, _Runtime, _TaskHeader, _FiberView
from fp.effects import CancellationToken, IOContext, Outcome, EffectFailure
from fp.effects.outcomes import _failure_as
from fp.effects._io_core import _Reporter
from .kernel import Machine, Step, Wait, _Slot, _Scheduled, _tick, _report_to_stderr
from .time import Instant
from .erased import _ErasedMachine


struct FiberStatus(Copyable, Equatable, Writable):
    """Where a live fiber stands in a driver snapshot."""
    var _code: Int

    @staticmethod
    def runnable() -> Self:
        """Ready to run on a coming poll, including a fiber not yet entered.

        Returns:
            The runnable status.
        """
        return Self(_code=0)

    @staticmethod
    def suspended() -> Self:
        """Parked until a signal, timer, or cancellation wakes it.

        Returns:
            The suspended status.
        """
        return Self(_code=1)

    @staticmethod
    def draining() -> Self:
        """Its program has finished; it waits for its own children to finish.

        Returns:
            The draining status.
        """
        return Self(_code=2)

    def __init__(out self, *, _code: Int):
        self._code = _code

    def __eq__(self, other: Self) -> Bool:
        return self._code == other._code

    def __ne__(self, other: Self) -> Bool:
        return self._code != other._code

    def write_to(self, mut writer: Some[Writer]):
        """Write the status name: runnable, suspended, or draining.

        Args:
            writer: The destination.
        """
        if self._code == 0:
            writer.write("runnable")
        elif self._code == 1:
            writer.write("suspended")
        else:
            writer.write("draining")


@fieldwise_init
struct FiberInfo(Copyable, Writable):
    """One live fiber in a driver snapshot, without payloads or completed work.

    There is no public fiber identity, as in Cats Effect: the index names a
    slot of the root IO's fiber table and is reused once the fiber completes.
    """
    var index: Int
    """The fiber's slot, from 1; 0 is the root program itself."""
    var owner: Int
    """The slot of the fiber that started it, or 0 for the root program."""
    var status: FiberStatus
    """Runnable, suspended, or draining its children."""


def _fiber_infos(views: List[_FiberView]) -> List[FiberInfo]:
    """A driver snapshot from the scheduler's table of live fibers."""
    var fibers = List[FiberInfo]()
    for view in views:
        var status = FiberStatus.runnable()
        if view.status == 1:
            status = FiberStatus.suspended()
        elif view.status == 2:
            status = FiberStatus.draining()
        fibers.append(FiberInfo(view.index, view.owner, status^))
    return fibers^


struct _FiberRecord[E: Movable & Deinitable](Movable):
    """What a fiber's handle shares with its task, typed only by E."""
    var token: CancellationToken
    var signal: Signal
    # The settled outcome; a success holds the handle's T, erased.
    var outcome: Optional[Outcome[_Erased, Self.E]]
    var done: Bool
    # Set once the last claim to the outcome is gone; it can no longer be joined.
    var released: Bool
    var report: Bool
    var reporter: _Reporter

    def __init__(out self):
        self.token = CancellationToken()
        self.signal = Signal()
        self.outcome = None
        self.done = False
        self.released = False
        self.report = True
        self.reporter = _report_to_stderr

    def identity(self) -> Int:
        return Int(self.signal._cell.ptr())

    def settle(mut self):
        """Dispose of an outcome nobody can join: report a failure, drop a success."""
        if not self.done or not self.released or not self.outcome:
            return
        var outcome = self.outcome.take()
        if not outcome or outcome.value().is_ok() or not self.report:
            return
        self.reporter(_describe(outcome.take()._take_err()))


def _describe[E: Movable & Deinitable](var failure: EffectFailure[E]) -> String:
    """One line for an unhandled failure: its errors, or their type and count."""
    var line = String("unhandled fiber failure: ")
    var canceled = failure.canceled
    var errors = failure^.into_errors().into_list()
    comptime if conforms_to(E, Writable):
        for index in range(len(errors)):
            if index:
                line.write("; ")
            line.write(rebind[downcast[E, Writable]](errors[index]))
    else:
        line.write(len(errors), " error(s) of type ", reflect[E].name())
    if canceled:
        line.write(" (canceled)")
    return line


struct _Claim[E: Movable & Deinitable](Movable):
    """The single right to a fiber's outcome, held by its handle and then by its join.

    Dropping the claim without taking the outcome releases the record: a
    failure is reported, now or when the child completes, and a success is
    destroyed once.
    """
    var record: ArcPointer[_FiberRecord[Self.E]]

    def __init__(out self, var record: ArcPointer[_FiberRecord[Self.E]]):
        self.record = record^

    def __deinit__(deinit self):
        self.record[].released = True
        self.record[].settle()

    def keep(deinit self) -> ArcPointer[_FiberRecord[Self.E]]:
        """Consume the claim after taking the outcome; nothing is left to release."""
        return self.record^


struct _Scope[E: Movable & Deinitable](Movable):
    """The fibers one run loop started that have not yet completed.

    `live` counts them atomically: admission increments it, and each child's
    completion decrements it and notifies `signal` when it reaches zero, which
    wakes an owner draining its children. The list keeps their records so the
    owner can cancel them; it is guarded by `lock`, and completed records are
    pruned as children are added.
    """
    var live: Atomic[Int]
    var signal: Signal
    var lock: Atomic[UInt8]
    var children: List[ArcPointer[_FiberRecord[Self.E]]]
    # The diagnostic slot of the fiber whose run loop owns this scope; 0 for
    # the root program, -1 until the first child is admitted.
    var fiber: Int

    def __init__(out self):
        self.live = Atomic(0)
        self.signal = Signal()
        self.lock = Atomic(UInt8(0))
        self.children = List[ArcPointer[_FiberRecord[Self.E]]]()
        self.fiber = -1

    def acquire(mut self):
        # Acquire: the previous holder's list updates are visible.
        _acquire_lock[256, Ordering.ACQUIRE, Ordering.RELAXED](self.lock)

    def release(mut self):
        _release_lock[Ordering.RELEASE](self.lock)

    def count(self) -> Int:
        # Acquire pairs with a completing child's decrement, so its published
        # outcome is visible once the count reads zero.
        return self.live.load[ordering=Ordering.ACQUIRE]()

    def adopt(mut self, record: ArcPointer[_FiberRecord[Self.E]]):
        self.acquire()
        if len(self.children) > 2 * self.count() + 8:
            var kept = List[ArcPointer[_FiberRecord[Self.E]]]()
            for child in self.children:
                if not child[].done:
                    kept.append(child.copy())
            self.children = kept^
        self.children.append(record.copy())
        _ = self.live.fetch_add[ordering=Ordering.ACQUIRE_RELEASE](1)
        self.release()

    def child_completed(mut self):
        """A child completed: the last one wakes a draining owner."""
        # Acquire-release orders the child's published outcome before the
        # owner's acquire load of the count.
        if self.live.fetch_sub[ordering=Ordering.ACQUIRE_RELEASE](1) == 1:
            self.signal.notify()

    def cancel_children(mut self):
        """Request cancellation of every live child, outside the list's lock."""
        self.acquire()
        var tokens = List[CancellationToken]()
        for child in self.children:
            if not child[].done:
                tokens.append(child[].token.copy())
        self.release()
        for token in tokens:
            token.cancel()


struct _Spawn[E: Movable & Deinitable](Movable):
    """A started child waiting for admission: its run loop as an erased machine."""
    var program: _ErasedMachine[_Erased, Self.E]
    var record: ArcPointer[_FiberRecord[Self.E]]
    # The child's own scope, and the scope that owns the child.
    var scope: ArcPointer[_Scope[Self.E]]
    var owner: ArcPointer[_Scope[Self.E]]

    def __init__(out self, var program: _ErasedMachine[_Erased, Self.E], var record: ArcPointer[_FiberRecord[Self.E]], var scope: ArcPointer[_Scope[Self.E]], var owner: ArcPointer[_Scope[Self.E]]):
        owner[].adopt(record)
        self.program = program^
        self.record = record^
        self.scope = scope^
        self.owner = owner^

    def admit(deinit self, context: IOContext[Self.E]):
        """Make the child a task of the root's executor, with its own registry and token."""
        if not context._runtime:
            abort("fibers start only under a driver")
        ref parent = context._runtime.value()
        var scheduler = parent.scheduler()
        if self.owner[].fiber < 0:
            self.owner[].fiber = parent.fiber()
        var child = IOContext[Self.E](self.record[].token.copy(), False)
        child._clock = context._clock.copy()
        child._budget = context._budget.copy()
        child._fiber = self.record[].identity()
        if context._budget:
            self.record[].report = context._budget.value()[].report
            self.record[].reporter = context._budget.value()[].reporter
        var task = ArcPointer(_TaskHeader(_Erased(), _run_fiber[Self.E]))
        var fiber = scheduler[].register_fiber(self.owner[].fiber, task)
        self.scope[].fiber = fiber
        var runtime = parent.fork(fiber)
        child._runtime = Optional(runtime.copy())
        var slot = _Slot[_ErasedMachine[_Erased, Self.E], _Erased, Self.E](self.program^)
        # The slot's registration starts ready; the hook queues the task below.
        slot.prepare(child)
        task[].body = _Erased(_FiberTask[Self.E](slot^, child^, self.record^, self.scope^, self.owner^, fiber))
        task[].registry = Optional(runtime.copy())
        runtime.attach(task)


struct _FiberTask[E: Movable & Deinitable](Movable):
    """A fiber's body as a task: its run loop's slot, context and ownership.

    The slot is registered at the root of the fiber's own registry. When the
    program is terminal, the task holds its settled outcome, cancels its live
    children, and waits on its scope's signal until they have all completed.
    """
    var slot: _Slot[_ErasedMachine[_Erased, Self.E], _Erased, Self.E]
    var context: IOContext[Self.E]
    var record: ArcPointer[_FiberRecord[Self.E]]
    var scope: ArcPointer[_Scope[Self.E]]
    var owner: ArcPointer[_Scope[Self.E]]
    var fiber: Int
    var held: Optional[Outcome[_Erased, Self.E]]
    var drain: Optional[_Scheduled]

    def __init__(out self, var slot: _Slot[_ErasedMachine[_Erased, Self.E], _Erased, Self.E], var context: IOContext[Self.E], var record: ArcPointer[_FiberRecord[Self.E]], var scope: ArcPointer[_Scope[Self.E]], var owner: ArcPointer[_Scope[Self.E]], fiber: Int):
        self.slot = slot^
        self.context = context^
        self.record = record^
        self.scope = scope^
        self.owner = owner^
        self.fiber = fiber
        self.held = None
        self.drain = None

    def run(mut self) -> Bool:
        """Run once; true when the fiber has completed."""
        if not self.held:
            _ = _tick(self.slot, self.context)
            if not self.slot.done():
                return False
            var outcome = self.slot.take_outcome()
            if not self.scope[].count():
                self.complete(outcome^)
                return True
            self.held = Optional(outcome^)
            self.context._runtime.value().scheduler()[].set_draining(self.fiber)
            self.scope[].cancel_children()
            self.drain = Optional(_Scheduled(self.context._runtime.value(), None, 1))
        # Read the revision before the count, so a completion between them wakes.
        var revision = self.scope[].signal.revision()
        self.drain.value().begin()
        if not self.scope[].count():
            self.drain = None
            self.complete(self.held.take())
            return True
        var wait = Wait.changed(self.scope[].signal, revision)
        wait._interruptible = False
        self.drain.value().arm(wait, self.context)
        return False

    def complete(mut self, var outcome: Outcome[_Erased, Self.E]):
        """Publish the outcome, release the claim's settlement, and leave the owner."""
        self.record[].outcome = Optional(outcome^)
        self.record[].done = True
        self.record[].signal.notify()
        self.record[].settle()
        self.context._runtime.value().scheduler()[].release_fiber(self.fiber)
        self.owner[].child_completed()


def _run_fiber[E: Movable & Deinitable](mut body: _Erased) -> Bool:
    return body.pointer[_FiberTask[E]]()[].run()


struct _Join[E: Movable & Deinitable](Machine):
    """Wait for the child, then hand its outcome and the claim to a delivery."""
    comptime Value = _Delivery[Self.E]
    comptime Error = Self.E
    var claim: Optional[_Claim[Self.E]]

    def __init__(out self, var claim: _Claim[Self.E]):
        self.claim = Optional(claim^)

    def poll(mut self, context: IOContext[Self.E]) -> Step[_Delivery[Self.E], Self.E]:
        ref record = self.claim.value().record[]
        if context._fiber and context._fiber == record.identity():
            abort("a fiber cannot join itself")
        var revision = record.signal.revision()
        # A canceled joiner leaves the outcome; dropping its claim reports it.
        if context.canceled():
            return Step[Self.Value, Self.E].ready(None)
        if record.done:
            var outcome = record.outcome.take()
            var delivery = _Delivery[Self.E](self.claim.take(), Optional(outcome^))
            return Step[Self.Value, Self.E].ready(Optional(Result[Self.Value, EffectFailure[Self.E]](Ok(delivery^))))
        return Step[Self.Value, Self.E].pending(Wait.changed(record.signal, revision))


struct _Delivery[E: Movable & Deinitable](Movable):
    """A joined outcome on its way to the joiner's continuation.

    If cancellation drops it before the join's own frame takes the outcome, the
    outcome returns to the record and the claim's release reports a failure.
    """
    var claim: _Claim[Self.E]
    var outcome: Optional[Outcome[_Erased, Self.E]]

    def __init__(out self, var claim: _Claim[Self.E], var outcome: Optional[Outcome[_Erased, Self.E]]):
        self.claim = claim^
        self.outcome = outcome^

    def __deinit__(deinit self):
        if self.outcome:
            self.claim.record[].outcome = self.outcome^
        # The claim's release settles the record.

    def take(deinit self) -> Outcome[_Erased, Self.E]:
        _ = self.claim^.keep()
        return self.outcome.take()


struct _Unwrap[T: Movable & Deinitable, E: Movable & Deinitable](OnceUnary, Defaultable):
    """The join's own frame: the outcome reaches the joiner, typed as T."""
    comptime Arg = _Delivery[Self.E]
    comptime Out = Outcome[Self.T, Self.E]

    def __init__(out self):
        pass

    def call_once(deinit self, var delivery: _Delivery[Self.E]) -> Outcome[Self.T, Self.E]:
        return _typed[Self.T](delivery^.take())


def _typed[T: Movable & Deinitable, E: Movable & Deinitable](var outcome: Outcome[_Erased, E]) -> Outcome[T, E]:
    """A fiber's settled outcome, its success unboxed as the T its IO type fixed."""
    if outcome and outcome.value().is_ok():
        return Optional(Result[T, EffectFailure[E]](Ok(outcome.take()._take_ok().take[T]())))
    return _failure_as[T](outcome^)


def _unsuccessful[E: Movable & Deinitable](record: _FiberRecord[E]) -> Bool:
    """Whether a finished fiber failed or was canceled."""
    if not record.done or not record.outcome:
        return False
    ref outcome = record.outcome.value()
    return not outcome or outcome.value().is_err()


@fieldwise_init
struct _FirstDone[E: Movable & Deinitable](Machine):
    """Wait for the first of two fibers to finish: true when the left one did.

    The left fiber wins a tie. A caller canceled while waiting cancels both
    fibers and completes canceled only after both finish.
    """
    comptime Value = Bool
    comptime Error = Self.E
    var left: ArcPointer[_FiberRecord[Self.E]]
    var right: ArcPointer[_FiberRecord[Self.E]]
    var stopping: Bool

    def poll(mut self, context: IOContext[Self.E]) -> Step[Bool, Self.E]:
        var left_revision = self.left[].signal.revision()
        var right_revision = self.right[].signal.revision()
        if not self.stopping and context.canceled():
            self.stopping = True
            self.left[].token.cancel()
            self.right[].token.cancel()
        if self.stopping:
            if self.left[].done and self.right[].done:
                return Step[Bool, Self.E].ready(None)
        elif self.left[].done:
            return Step[Bool, Self.E].ready(Optional(Result[Bool, EffectFailure[Self.E]](Ok(True))))
        elif self.right[].done:
            return Step[Bool, Self.E].ready(Optional(Result[Bool, EffectFailure[Self.E]](Ok(False))))
        var either = Wait.changed(self.left[].signal, left_revision)
        var other = Wait.changed(self.right[].signal, right_revision)
        # Once draining, the caller's own request must not wake it again.
        either._interruptible = not self.stopping
        other._interruptible = not self.stopping
        either._include(other, context)
        return Step[Bool, Self.E].pending(either^)


@fieldwise_init
struct _CancelFiber[E: Movable & Deinitable](Machine):
    comptime Value = NoneType
    comptime Error = Self.E
    var record: ArcPointer[_FiberRecord[Self.E]]
    var requested: Bool

    def poll(mut self, context: IOContext[Self.E]) -> Step[NoneType, Self.E]:
        ref record = self.record[]
        var revision = record.signal.revision()
        if not self.requested:
            record.token.cancel()
            self.requested = True
        if record.done:
            return _unit[Self.E]()
        var wait = Wait.changed(record.signal, revision)
        wait._interruptible = False
        return Step[NoneType, Self.E].pending(wait^)


@fieldwise_init
struct _RequestCancel[E: Movable & Deinitable](Machine):
    comptime Value = NoneType
    comptime Error = Self.E
    var record: ArcPointer[_FiberRecord[Self.E]]

    def poll(mut self, context: IOContext[Self.E]) -> Step[NoneType, Self.E]:
        self.record[].token.cancel()
        return _unit[Self.E]()


def _unit[E: Movable & Deinitable]() -> Step[NoneType, E]:
    var unit: NoneType = None
    return Step[NoneType, E].ready(Optional(Result[NoneType, EffectFailure[E]](Ok(unit))))
