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

A scope is used by several tasks at once, so its methods take immutable `self`
and its atomics live in separate allocations: a `mut` borrow is exclusive in
Mojo, and an inline atomic reached through concurrent exclusive borrows can
lose updates. A record's terminal state is one lock-free decision on its
one-shot slot, and a scope's children sit on a closable lock-free stack, so
completion, joins, claim release and adoption take no lock.
"""
from std.atomic import Atomic, Ordering
from std.builtin.rebind import downcast
from std.memory import ArcPointer
from std.os import abort
from fp.callables import OnceUnary
from fp.data import Result, Ok
from fp._internal.erased import _Erased
from fp._internal.oneshot import _OneShot
from fp._internal.closable_stack import _ClosableStack, _StackLink, _Linked
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
    """What a fiber's handle shares with its task, typed only by E.

    The settled outcome lives in a one-shot slot (`fp._internal.oneshot`): the
    fiber's task is its only writer, and the handle's claim, then its join, is
    the receiver. Exactly one party disposes of an outcome nobody joins:

    - the joiner, which takes it in one step that also consumes the claim;
    - the claim's release, when the outcome was already published;
    - the completing task, when the claim was released first.

    A disposed failure is reported, and a disposed success destroyed, once,
    on whichever thread wins. `report` and `reporter` are fixed when the record
    is created, before the handle exists, so every thread reads them
    unchanged. `done` is a lock-free acquire load: a reader that sees it also
    sees everything the child wrote before completing.
    """
    # The record's place on its owner scope's stack (`_Child`): written only
    # by the stack's protocol, never through the record's own methods. First,
    # so that adoption, which copies the handle, writes the line that holds
    # the reference count it already touches.
    var link: _StackLink[_Child[Self.E]]
    var token: CancellationToken
    var signal: Signal
    # The settled outcome; a success holds the handle's T, erased.
    var outcome: _OneShot[Outcome[_Erased, Self.E]]
    var report: Bool
    var reporter: _Reporter

    def __init__(out self, report: Bool = True, reporter: _Reporter = _report_to_stderr):
        self.link = _StackLink[_Child[Self.E]]()
        self.token = CancellationToken()
        self.signal = Signal()
        self.outcome = _OneShot[Outcome[_Erased, Self.E]]()
        self.report = report
        self.reporter = reporter

    def identity(self) -> Int:
        return Int(self.signal._cell.ptr())

    def done(self) -> Bool:
        """Whether the outcome is published; lock-free, from any thread."""
        return self.outcome.published()

    def complete(self, var outcome: Outcome[_Erased, Self.E]):
        """Publish the outcome once, from the fiber's task, and wake its waiters.

        If the claim was already released, nobody can join: the task disposes
        of the outcome itself, after notifying.
        """
        var unclaimed = self.outcome.put(outcome^)
        self.signal.notify()
        if unclaimed:
            self.dispose(unclaimed.take())

    def release(self):
        """The claim is gone without taking the outcome: dispose of it if published."""
        var published = self.outcome.release()
        if published:
            self.dispose(published.take())

    def take(self) -> Outcome[_Erased, Self.E]:
        """The claim's holder takes the published outcome, consuming the claim."""
        var taken = self.outcome.take[release=True]()
        if not taken:
            abort("a fiber's outcome was taken before it was published")
        return taken.take()

    def dispose(self, var outcome: Outcome[_Erased, Self.E]):
        """Report an unjoined failure, or destroy an unjoined success, on this thread."""
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
        self.record[].release()

    def take(deinit self) -> Outcome[_Erased, Self.E]:
        """Take the published outcome; the same step consumes the claim."""
        var record = self.record^
        return record[].take()

    def keep(deinit self) -> ArcPointer[_FiberRecord[Self.E]]:
        """Consume the claim after the outcome was taken; nothing is left to release."""
        return self.record^


comptime _CLOSE_CANCEL = UInt8(0)
"""A scope's stack closed by its owner's drain or a supervisor's release: live children are canceled."""
comptime _CLOSE_KEEP = UInt8(1)
"""Closed by a supervisor awaiting its children on release: they run to completion."""


struct _Child[E: Movable & Deinitable](_Linked):
    """A scope's handle to a child's record; the record itself is the stack's node."""
    var record: ArcPointer[_FiberRecord[Self.E]]

    def __init__(out self, var record: ArcPointer[_FiberRecord[Self.E]]):
        self.record = record^

    def _link_address(self) -> Int:
        return Int(Pointer(to=self.record[].link))


def _live[E: Movable & Deinitable](child: _Child[E]) -> Bool:
    return not child.record[].done()


comptime _LIVE_MASK = 0xFFFFFFFF
"""The low half of a scope's count word: live children."""
comptime _LISTED_ONE = 1 << 32
"""One listed child, in the high half of the count word."""


struct _ScopeCounts(Movable):
    """A scope's atomics, in their own allocation.

    `children` packs two counts in one word, so an adoption changes both with
    one `fetch_add`: the live children in the low 32 bits, and in the high 32
    bits the children listed on the stack, an upper bound that decides when to
    prune (the stack keeps no length, so pushes contend on its head alone).
    Live never drops below zero, so changing the low half never borrows from
    the high one. It changes with ACQUIRE_RELEASE and is read with ACQUIRE
    (see `_Scope`). `fiber` is diagnostic metadata, a slot number that orders
    no other data, so it is read and written RELAXED; it is atomic because a
    supervisor's scope is reached from every fiber that supervises.
    """
    var children: Atomic[Int]
    var fiber: Atomic[Int]

    def __init__(out self):
        self.children = Atomic(0)
        self.fiber = Atomic(-1)


struct _Scope[E: Movable & Deinitable](Movable):
    """The fibers one run loop, or one supervisor, started that have not yet completed.

    `live` counts them atomically: adoption increments it, and each child's
    completion decrements it and notifies `signal` when it reaches zero, which
    wakes an owner draining its children. The children's records sit on a
    closable lock-free stack (`fp._internal.closable_stack`), so the owner, or
    the supervisor's release, can close it once and cancel every live child.
    Adoption pushes unless the stack is closed: a refused child never runs.
    Completed records are pruned as children are adopted; a prune that finds
    the stack closed treats its survivors as the close did, by its tag.

    Children complete on their own tasks and a supervisor's children are
    adopted from any fiber, so several threads may use one scope at once:
    every method takes immutable `self`, and the counter and the stack live
    in their own allocations (see the module docstring).
    """
    var counts: ArcPointer[_ScopeCounts]
    var signal: Signal
    var children: _ClosableStack[_Child[Self.E]]

    def __init__(out self):
        self.counts = ArcPointer(_ScopeCounts())
        self.signal = Signal()
        self.children = _ClosableStack[_Child[Self.E]]()

    def fiber(self) -> Int:
        """The diagnostic slot of the fiber whose run loop owns this scope, or -1 until known."""
        return self.counts[].fiber.load[ordering=Ordering.RELAXED]()

    def set_fiber(self, fiber: Int):
        """Fix the owning fiber's slot, when that fiber is admitted."""
        self.counts[].fiber.store[ordering=Ordering.RELAXED](fiber)

    def guess_fiber(self, fiber: Int) -> Int:
        """The owner's slot, taking `fiber` if none is known yet; for a scope first used before its fiber's admission."""
        var expected = -1
        if self.counts[].fiber.compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.RELAXED](expected, fiber):
            return fiber
        return expected

    def count(self) -> Int:
        # Acquire pairs with a completing child's decrement, so its published
        # outcome is visible once the count reads zero.
        return self.counts[].children.load[ordering=Ordering.ACQUIRE]() & _LIVE_MASK

    def adopt(self, record: ArcPointer[_FiberRecord[Self.E]]) -> Bool:
        """Count and list a child; false when the scope is closed and the child must not run.

        The count rises before the push, so an owner that drains after the
        push sees the child; a refused child is uncounted again.
        """
        # Acquire-release, as every change of the count (see child_completed).
        var counts = self.counts[].children.fetch_add[ordering=Ordering.ACQUIRE_RELEASE](_LISTED_ONE + 1) + _LISTED_ONE + 1
        if self.children.push(_Child[Self.E](record.copy())):
            _ = self.counts[].children.fetch_sub[ordering=Ordering.RELAXED](_LISTED_ONE)
            self.child_completed()
            return False
        if counts >> 32 > 2 * (counts & _LIVE_MASK) + 8:
            var pruned = self.children.prune[_live[Self.E]]()
            # RELAXED: the listed half orders nothing.
            _ = self.counts[].children.fetch_sub[ordering=Ordering.RELAXED](pruned.removed * _LISTED_ONE)
            if pruned.tag == _CLOSE_CANCEL:
                for index in range(len(pruned.orphans)):
                    pruned.orphans[index].record[].token.cancel()
        return True

    def child_completed(self):
        """A child completed: the last one wakes a draining owner."""
        # Acquire-release orders the child's published outcome before the
        # owner's acquire load of the count.
        if (self.counts[].children.fetch_sub[ordering=Ordering.ACQUIRE_RELEASE](1) & _LIVE_MASK) == 1:
            self.signal.notify()

    def close(self, tag: UInt8) -> List[_Child[Self.E]]:
        """Refuse later children and return the listed ones, oldest first."""
        return self.children.close(tag)

    def cancel_children(self):
        """Close the scope and request cancellation of every live child."""
        var children = self.close(_CLOSE_CANCEL)
        for index in range(len(children)):
            if not children[index].record[].done():
                children[index].record[].token.cancel()


struct _Spawn[E: Movable & Deinitable](Movable):
    """A started child waiting for admission: its run loop as an erased machine."""
    var program: _ErasedMachine[_Erased, Self.E]
    var record: ArcPointer[_FiberRecord[Self.E]]
    # The child's own scope, and the scope that owns the child.
    var scope: ArcPointer[_Scope[Self.E]]
    var owner: ArcPointer[_Scope[Self.E]]

    def __init__(out self, var program: _ErasedMachine[_Erased, Self.E], var record: ArcPointer[_FiberRecord[Self.E]], var scope: ArcPointer[_Scope[Self.E]], var owner: ArcPointer[_Scope[Self.E]]):
        """A child its owner already adopted (`_Scope.adopt`)."""
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
        var owner_slot = self.owner[].guess_fiber(parent.fiber())
        var child = IOContext[Self.E](self.record[].token.copy(), False)
        child._clock = context._clock.copy()
        child._budget = context._budget.copy()
        child._fiber = self.record[].identity()
        var task = ArcPointer(_TaskHeader(_Erased(), _run_fiber[Self.E]))
        var fiber = scheduler[].register_fiber(owner_slot, task)
        self.scope[].set_fiber(fiber)
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
        """Publish the outcome (or dispose of it if unclaimed), then leave the owner."""
        self.record[].complete(outcome^)
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
        if record.done():
            var delivery = _Delivery[Self.E](self.claim.take())
            return Step[Self.Value, Self.E].ready(Optional(Result[Self.Value, EffectFailure[Self.E]](Ok(delivery^))))
        return Step[Self.Value, Self.E].pending(Wait.changed(record.signal, revision))


struct _Delivery[E: Movable & Deinitable](Movable):
    """A joined outcome on its way to the joiner's continuation.

    The join took the outcome and consumed the claim in one step, so the
    delivery owns it. If cancellation drops the delivery before the join's own
    frame takes the outcome, the delivery disposes of it as an unjoined
    outcome: a failure is reported, a success destroyed.
    """
    var record: ArcPointer[_FiberRecord[Self.E]]
    var outcome: Optional[Outcome[_Erased, Self.E]]

    def __init__(out self, var claim: _Claim[Self.E]):
        """Take the published outcome through the claim."""
        var record = claim.record.copy()
        self.outcome = Optional(claim^.take())
        self.record = record^

    def __deinit__(deinit self):
        if self.outcome:
            self.record[].dispose(self.outcome.take())

    def take(deinit self) -> Outcome[_Erased, Self.E]:
        var outcome = self.outcome.take()
        _ = self.record^
        return outcome^


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
    """Whether a finished fiber failed or was canceled; only for the holder of its claim.

    The holder alone may take or release the outcome, so it stays in place
    while the holder reads it.
    """
    if not record.done():
        return False
    ref outcome = record.outcome.peek()[]
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
            if self.left[].done() and self.right[].done():
                return Step[Bool, Self.E].ready(None)
        elif self.left[].done():
            return Step[Bool, Self.E].ready(Optional(Result[Bool, EffectFailure[Self.E]](Ok(True))))
        elif self.right[].done():
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
        if record.done():
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
