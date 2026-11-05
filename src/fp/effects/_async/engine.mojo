"""IO, its Async family, and the private run loop that evaluates IO programs iteratively.

An IO is a head (a value, a failure, a leaf machine, or a deferred factory) and
the continuation frames applied after it. `flat_map` appends a frame, and
entering a program pushes its frames onto one run-loop stack, so evaluation,
unwinding and disposal never recurse natively. Callbacks run once through the
canonical receiver adapters and install the program they build directly into
the run loop. Small values and callbacks live inline in their erased boxes, so a
common bind allocates nothing. Typed machines run as leaves through the
canonical slot; failures keep their exact error type because one IO chain
shares it.
"""
from std.builtin.rebind import downcast, rebind_var
from std.iter import Iterator, IterableOwned
from std.memory import OwnedPointer, MaybeUninit, ArcPointer
from std.os import abort
from std.atomic import Atomic, Ordering
from fp.algebra.protocols import Parallel, Applicative, Monad, ErrorRecovery, _FamilyCarrier, _Accumulate, _LiveAccumulator, _AccumulatePair, _start_as, _combine_as, _LimitedLoop
from fp.callables.protocols import UnaryContract, BinaryContract, ThunkContract, BorrowCallContract, BorrowCallable, OnceUnary, OnceThunk, MutableBinary
from fp.callables.invoke import _OnceUnaryAvailable, _OnceBinaryAvailable, _OnceThunkAvailable, _OnceBorrowAvailable, RepeatableUnary, RepeatableBinary
from fp.callables._receiver import _unary_once_as, _thunk_once_as, _borrow_once_as, _unary_repeated_as, _binary_repeated_as
from fp.callables._binding import _BindFirst
from fp.callables._identity import Identity
from fp.callables._views import _BorrowedView
from fp.callables.native import NativeUnary, _NativeThunk, _NativeOwnedArg, _NativeBorrow
from fp.algebra._outcomes import _Materialize
from fp.iteration._advance import _Source, _source, _next_optional
from fp._internal.erased import _Erased
from fp._internal.closable_stack import _ClosableStack, _StackLink, _Linked
from fp._internal.waking import _Event as _Signal
from fp.functions.tupled import Tupled
from fp._internal.errors import _ErrorCompatible
from fp.data import Result, Ok, Err, NonEmptyList, Left, Right
from fp.effects import IOContext, Outcome, EffectFailure, ExitCase
from fp.effects.outcomes import _failure_as, _finish, _ExitState, _zip_outcomes
from fp.effects._io_core import _settle, IOContract, _Reporter, canceled as _cancel_request
from fp.effects.protocols import ReaderAction, Defer, Raise, Spawn, Concurrent, Temporal, Blocking, EvalOn
from fp.effects._timing import _SleepSource, _timed, _delay_by, _and_wait
from fp.effects.finalization import Poll as _SyncPoll
from fp.effects.coordination import Ref as _Ref, Deferred as _Deferred, _RefInspect, _Copy
from .kernel import IORuntimeConfig, Machine, Step, Wait, _Slot, _tick, Sleep as _Sleep, _report_to_stderr
from .time import Duration, Instant, SystemTime
from .racing import RaceResult, _winner, _loser
from .io import EvalIO as _EvalIO
from .blocking import _CallValue, _CurrentBlocking, _SubmitBlocking, _SubmitInterruptible, _AwaitReturn, _Interrupt
from .scheduling.blocking_pool import _RootBlocking
from fp.effects._interruption import Interruption
from .callbacks import Callback as _Callback, Completion, _CallbackUnit
from .contexts import _SubmitRegion, _CurrentSettings, _CurrentContext
from .runtime import ExecutionContext
from fp.callables.protocols import Unary
from fp.callables.native import NativeBorrow
from fp.effects.resources import _MapScopeFactory
from .scopes import ScopedMachine, CleanupMachine, _ProgramUse
from .composition import Pure as _Pure, pure as _pure
from .resources import ResourcePlan, _AsyncResourceType, _Acquire, _Join as _ResourceJoin, _ScopedBuild, _acquire_release
from fp._internal.cells import _Cell, _lock_cell
from .erased import _ErasedMachine
from .finalization import Poll
from .attempts import _Once, _Await
from .fibers import _FiberRecord, _Scope, _Spawn, _Claim, _Join, _Delivery, _Unwrap, _CancelFiber, _RequestCancel, _FirstDone, _typed, _unsuccessful
from fp._internal.thread_safety import ThreadTransferable, _RootBound, _root_bound_rejection

# Head and frame kinds.
comptime _EMPTY = 0
comptime _PURE = 1
comptime _FAIL = 2
comptime _LEAF = 3
comptime _DEFER = 4
comptime _BIND = 5
comptime _RECOVER = 6
# Frames from _FINALIZE upward apply to every outcome.
comptime _FINALIZE = 7
comptime _FINISH = 8
comptime _REGION_EXIT = 9
comptime _MASK = 10
comptime _RESTORE = 11

# Run-loop states.
comptime _EVALUATE = 0
comptime _VALUE = 1
comptime _FAILURE = 2
comptime _CANCELED = 3
comptime _WAITING = 4

# Transitions per poll for a context without a root budget, such as a test
# polling an IO directly; roots take theirs from IORuntimeConfig.
comptime _BUDGET = 1024

comptime _Leaf[E: Movable & Deinitable] = _ErasedMachine[_Erased, E]

# A callback receives the run loop through an engine-fixed opaque pointer. Mojo
# 1.2 crashes compiling a stored function type whose signature contains its
# owner (_Frame -> _RunLoop -> _Frame).
comptime _Invoke = def(var _Erased, MutOpaquePointer[_]) thin


def _no_invoke(var callable: _Erased, loop: MutOpaquePointer[_]):
    abort("engine invoked a head without a callback")


struct _Head[E: Movable & Deinitable](Movable):
    """What a program evaluates first: a value, failure, leaf, or factory."""
    var kind: Int
    var box: _Erased
    var invoke: _Invoke

    def __init__(out self):
        self.kind = _EMPTY
        self.box = _Erased()
        self.invoke = _no_invoke

    def __init__(out self, kind: Int, var box: _Erased, invoke: _Invoke = _no_invoke):
        self.kind = kind
        self.box = box^
        self.invoke = invoke

    def take_box(mut self) -> _Erased:
        var box = _Erased()
        swap(box, self.box)
        self.kind = _EMPTY
        return box^


@fieldwise_init
struct _Frame(Movable):
    """One continuation: a bind applied to a value or a recovery applied to a failure."""
    var kind: Int
    var callable: _Erased
    var invoke: _Invoke

    def call(deinit self, loop: MutOpaquePointer[_]):
        self.invoke(self.callable^, loop)

    def take_callable(deinit self) -> _Erased:
        return self.callable^


struct _Frames(Movable):
    """Continuations in application order; the first lives inline."""
    var _first: MaybeUninit[_Frame]
    var _count: Int
    var _rest: List[_Frame]

    def __init__(out self):
        self._first = MaybeUninit[_Frame]()
        self._count = 0
        self._rest = List[_Frame]()

    def __deinit__(deinit self):
        # MaybeUninit of a non-trivial frame must be consumed on every path.
        if self._count:
            self._first^.unsafe_deinit()
        else:
            self._first^.unsafe_forget()

    def append(mut self, var frame: _Frame):
        if self._count:
            self._rest.append(frame^)
        else:
            self._first.unsafe_write(frame^)
        self._count += 1

    def push_onto(deinit self, mut stack: List[_Frame]):
        """Push so that the first continuation to apply ends on top."""
        var rest = self._rest^
        while len(rest):
            stack.append(rest.pop())
        if self._count:
            stack.append(self._first^.unsafe_assume_init())
        else:
            self._first^.unsafe_forget()


struct _Program[E: Movable & Deinitable](Movable):
    var head: _Head[Self.E]
    var frames: _Frames

    def __init__(out self, var head: _Head[Self.E]):
        self.head = head^
        self.frames = _Frames()

    def install_into(deinit self, mut loop: _RunLoop[Self.E]):
        loop.head = self.head^
        loop.state = _EVALUATE
        self.frames^.push_onto(loop.frames)


comptime _BuildCleanup[E: Movable & Deinitable] = def(var _Erased, ExitCase[E]) thin -> _Program[E]


def _no_cleanup[E: Movable & Deinitable](var factory: _Erased, exit: ExitCase[E]) -> _Program[E]:
    abort("engine built a cleanup without a factory")


@fieldwise_init
struct _Finalizer[E: Movable & Deinitable](Movable):
    """A cleanup program, or a factory building one from the borrowed exit case."""
    var only_cancel: Bool
    var program: Optional[_Program[Self.E]]
    var factory: _Erased
    var build: _BuildCleanup[Self.E]

    def cleanup(deinit self, exit: ExitCase[Self.E]) -> _Program[Self.E]:
        if self.program:
            return self.program.take()
        return self.build(self.factory^, exit)


@fieldwise_init
struct _Finishing[E: Movable & Deinitable](Movable):
    """The settled body exit retained while its cleanup runs masked."""
    var exit: _ExitState[_Erased, Self.E]
    var previous: Optional[IOContext[Self.E]]

    def complete(deinit self, mut loop: _RunLoop[Self.E], var cleanup: Outcome[_Erased, Self.E], base: IOContext[Self.E]):
        # Body errors precede cleanup errors; settlement uses the restored context.
        var combined = _finish(self.exit^.outcome(), cleanup^)
        loop.override = self.previous^
        loop.protected = False
        loop.switched = True
        if loop.override:
            loop.put_outcome(_settle(combined^, loop.override.value()))
        else:
            loop.put_outcome(_settle(combined^, base))


@fieldwise_init
struct _RegionExit[E: Movable & Deinitable](Movable):
    """Restore the context in effect before a mask or restore region."""
    var previous: Optional[IOContext[Self.E]]
    var protects: Bool

    def complete(deinit self, mut loop: _RunLoop[Self.E]):
        loop.override = self.previous^
        loop.switched = True
        if self.protects:
            # A masked region's success survives cancellation until the next checkpoint.
            loop.protected = True


@fieldwise_init
struct _Restore[E: Movable & Deinitable](Movable):
    """Run a program under a region's previous cancellation state."""
    var poll: Poll[Self.E]
    var program: _Program[Self.E]

    def enter(deinit self, mut loop: _RunLoop[Self.E], context: IOContext[Self.E]):
        loop.frames.append(_Frame(_REGION_EXIT, _Erased(_RegionExit[Self.E](loop.take_override(), False)), _no_invoke))
        loop.override = Optional(self.poll._source._restore(context))
        loop.switched = True
        self.program^.install_into(loop)


struct _RunLoop[E: Movable & Deinitable](Movable):
    """Evaluate heads and deliver outcomes through one explicit frame stack."""
    var state: Int
    var head: _Head[Self.E]
    var value: _Erased
    var failure: Optional[EffectFailure[Self.E]]
    var frames: List[_Frame]
    var leaf: Optional[_Slot[_Leaf[Self.E], _Erased, Self.E]]
    var protected: Bool
    # The masked or restored context of the innermost open region, if any.
    var override: Optional[IOContext[Self.E]]
    var poll: Optional[Poll[Self.E]]
    var switched: Bool
    # Handoffs left before the next cancellation check, and the interval.
    var until_check: Int
    var check_every: Int
    # The fibers this loop started: the ownership scope that drains them, and
    # those started during the current run segment, admitted when it ends.
    var scope: Optional[ArcPointer[_Scope[Self.E]]]
    var pending: List[_Spawn[Self.E]]
    # A terminal step held while the scope's children drain.
    var held: Optional[Step[_Erased, Self.E]]
    # The root's failure reporting, read from the budget's shared, read-only
    # configuration when a segment starts; records started here are fixed to it.
    var report: Bool
    var reporter: _Reporter

    def __init__(out self, var program: _Program[Self.E]):
        self.state = _EVALUATE
        self.head = _Head[Self.E]()
        self.value = _Erased()
        self.failure = None
        self.frames = List[_Frame]()
        self.leaf = None
        self.protected = False
        self.override = None
        self.poll = None
        self.switched = False
        self.until_check = 1
        self.check_every = 1
        self.scope = None
        self.pending = List[_Spawn[Self.E]]()
        self.held = None
        self.report = True
        self.reporter = _report_to_stderr
        program^.install_into(self)

    def spawn(mut self, var program: _Program[Self.E], var record: ArcPointer[_FiberRecord[Self.E]], owner: Optional[ArcPointer[_Scope[Self.E]]] = None) -> ArcPointer[_Scope[Self.E]]:
        """Start a child owned by this loop's scope, or by a supervisor's.

        The child is admitted to the executor when this run segment ends.
        Returns the child's own scope, which owns the fibers it starts. A
        closed owner, a released supervisor's, refuses the child: its record
        completes canceled at once and the program never runs.
        """
        var parent: ArcPointer[_Scope[Self.E]]
        if owner:
            parent = owner.value().copy()
        else:
            if not self.scope:
                self.scope = Optional(ArcPointer(_Scope[Self.E]()))
            parent = self.scope.value().copy()
        var scope = ArcPointer(_Scope[Self.E]())
        if not parent[].adopt(record):
            record[].token.cancel()
            record[].complete(Outcome[_Erased, Self.E]())
            return scope^
        var child = _RunLoop[Self.E](program^)
        child.scope = Optional(scope.copy())
        self.pending.append(_Spawn[Self.E](_Leaf[Self.E](_FiberLoop[Self.E](OwnedPointer(child^))), record^, scope.copy(), parent^))
        return scope^

    def record(self) -> ArcPointer[_FiberRecord[Self.E]]:
        """A new fiber record with the root's reporting configuration, fixed at creation."""
        return _FiberRecord[Self.E].new(self.report, self.reporter)

    def admit(mut self, context: IOContext[Self.E]):
        """Admit the fibers started during this segment, in start order."""
        var pending = List[_Spawn[Self.E]]()
        swap(pending, self.pending)
        pending.reverse()
        while len(pending):
            pending.pop().admit(context)

    def drain(mut self, var step: Optional[Step[_Erased, Self.E]]) -> Step[_Erased, Self.E]:
        """Complete only once this loop's started fibers have completed.

        Given a terminal step, cancels the live children and holds it; given
        none, continues holding. The wait cannot be interrupted, as an owner's
        drain cannot.
        """
        if step:
            if not self.scope or not self.scope.value()[].count():
                return step.take()
            self.scope.value()[].cancel_children()
            self.held = step^
        ref scope = self.scope.value()[]
        var revision = scope.signal.revision()
        if not scope.count():
            return self.held.take()
        var wait = Wait.changed(scope.signal, revision)
        wait._interruptible = False
        return Step[_Erased, Self.E].pending(wait^)

    def take_override(mut self) -> Optional[IOContext[Self.E]]:
        var previous: Optional[IOContext[Self.E]] = None
        swap(previous, self.override)
        return previous^

    def take_outcome(mut self) -> Outcome[_Erased, Self.E]:
        if self.state == _VALUE:
            return Optional(Result[_Erased, EffectFailure[Self.E]](Ok(self.take_value())))
        if self.state == _FAILURE:
            return Optional(Result[_Erased, EffectFailure[Self.E]](Err(self.failure.take())))
        return None

    def put_outcome(mut self, var outcome: Outcome[_Erased, Self.E]):
        if not outcome:
            self.state = _CANCELED
        elif outcome.value().is_ok():
            self.set_value(outcome.take()._take_ok())
        else:
            self.set_failure(outcome.take()._take_err())

    def address(mut self) -> MutOpaquePointer[origin_of(self)]:
        return Pointer(to=self).unsafe_bitcast[NoneType]()

    def take_value(mut self) -> _Erased:
        var value = _Erased()
        swap(value, self.value)
        return value^

    def set_value(mut self, var value: _Erased):
        self.value = value^
        self.state = _VALUE

    def set_failure(mut self, var failure: EffectFailure[Self.E]):
        self.failure = Optional(failure^)
        self.state = _FAILURE

    def run(mut self, context: IOContext[Self.E]) -> Step[_Erased, Self.E]:
        var budget = _BUDGET
        if context._budget:
            ref shared = context._budget.value()[]
            budget = shared.remaining
            self.check_every = shared.check_threshold
            self.report = shared.report
            self.reporter = shared.reporter
        while True:
            # Region boundaries switch the effective context; reselect it then.
            self.switched = False
            var step: Optional[Step[_Erased, Self.E]]
            if self.override:
                var current = self.override.value().copy()
                step = self.steps(current, context, budget)
            else:
                step = self.steps(context, context, budget)
            if step:
                _publish(context, budget)
                if len(self.pending):
                    self.admit(context)
                return step.take()

    def steps(mut self, context: IOContext[Self.E], base: IOContext[Self.E], mut budget: Int) -> Optional[Step[_Erased, Self.E]]:
        while budget > 0:
            budget -= 1
            if self.state == _EVALUATE:
                self.evaluate(context)
            elif self.state == _VALUE:
                if not len(self.frames):
                    var success: Outcome[_Erased, Self.E] = Optional(Result[_Erased, EffectFailure[Self.E]](Ok(self.take_value())))
                    return Optional(Step[_Erased, Self.E]._make(Optional(success^), Wait(), self.protected))
                var frame = self.frames.pop()
                if frame.kind == _BIND:
                    self.until_check -= 1
                    if self.until_check == 0:
                        self.until_check = self.check_every
                        if context.canceled():
                            # The handoff checkpoint drops the unopened continuation.
                            _ = self.take_value()
                            self.state = _CANCELED
                            continue
                    self.protected = False
                    frame^.call(self.address())
                elif frame.kind >= _FINALIZE:
                    self.unwind(frame^, context, base)
            elif self.state == _FAILURE:
                if not len(self.frames):
                    var failed: Outcome[_Erased, Self.E] = Optional(Result[_Erased, EffectFailure[Self.E]](Err(self.failure.take())))
                    return Optional(Step[_Erased, Self.E]._make(Optional(failed^), Wait(), self.protected))
                var frame = self.frames.pop()
                if frame.kind == _RECOVER and not self.failure.value().canceled:
                    self.until_check -= 1
                    if self.until_check == 0:
                        self.until_check = self.check_every
                        if context.canceled():
                            self.failure.value().canceled = True
                            continue
                    self.protected = False
                    frame^.call(self.address())
                elif frame.kind >= _FINALIZE:
                    self.unwind(frame^, context, base)
            elif self.state == _CANCELED:
                if not len(self.frames):
                    var canceled: Outcome[_Erased, Self.E] = None
                    return Optional(Step[_Erased, Self.E]._make(Optional(canceled^), Wait(), self.protected))
                var frame = self.frames.pop()
                if frame.kind >= _FINALIZE:
                    self.unwind(frame^, context, base)
            else:
                # A nested IO inside the leaf draws from the same root budget,
                # including this transition, so a threshold as small as one
                # still reaches it. The leaf poll counts only if it spent none.
                _publish(base, budget + 1)
                if not _tick(self.leaf.value(), context):
                    # A leaf that is not ready is not polled and counts nothing.
                    budget += 1
                    return Optional(Step[_Erased, Self.E].pending(self.leaf.value().waiting()))
                if base._budget:
                    budget = min(budget, base._budget.value()[].remaining)
                if not self.leaf.value().done():
                    return Optional(Step[_Erased, Self.E].pending(self.leaf.value().waiting()))
                self.finish_leaf()
            if self.switched:
                return None
        return Optional(Step[_Erased, Self.E].pending(Wait()))

    def unwind(mut self, var frame: _Frame, context: IOContext[Self.E], base: IOContext[Self.E]):
        """Apply a frame that every outcome reaches: cleanup or a region exit."""
        var kind = frame.kind
        var box = frame^.take_callable()
        if kind == _FINALIZE:
            self.finalize(box^.take[_Finalizer[Self.E]](), context)
        elif kind == _FINISH:
            var cleanup = self.take_outcome()
            box^.take[_Finishing[Self.E]]().complete(self, cleanup^, base)
        else:
            box^.take[_RegionExit[Self.E]]().complete(self)

    def finalize(mut self, var finalizer: _Finalizer[Self.E], context: IOContext[Self.E]):
        # Settle the body as a scope does, then run cleanup masked with its exact exit.
        var exit = _ExitState[_Erased, Self.E](_settle(self.take_outcome(), context, self.protected))
        if finalizer.only_cancel and not exit.exit.is_canceled():
            self.put_outcome(exit^.outcome())
            return
        var cleanup = finalizer^.cleanup(exit.exit)
        self.frames.append(_Frame(_FINISH, _Erased(_Finishing[Self.E](exit^, self.take_override())), _no_invoke))
        self.override = Optional(context._mask())
        self.switched = True
        cleanup^.install_into(self)

    def evaluate(mut self, context: IOContext[Self.E]):
        var kind = self.head.kind
        if kind == _PURE:
            self.protected = False
            self.set_value(self.head.take_box())
        elif kind == _FAIL:
            self.protected = False
            self.set_failure(self.head.take_box().take[EffectFailure[Self.E]]())
        elif kind == _DEFER:
            if context.canceled():
                _ = self.head.take_box()
                self.state = _CANCELED
                return
            var invoke = self.head.invoke
            invoke(self.head.take_box(), self.address())
        elif kind == _LEAF:
            self.leaf = Optional(_Slot[_Leaf[Self.E], _Erased, Self.E](self.head.take_box().take[_Leaf[Self.E]]()))
            self.state = _WAITING
        elif kind == _MASK:
            if context.canceled():
                _ = self.head.take_box()
                self.state = _CANCELED
                return
            var masked = context._mask()
            self.poll = Optional(Poll[Self.E](_SyncPoll[Self.E](context.copy(), masked._region.value().copy())))
            self.frames.append(_Frame(_REGION_EXIT, _Erased(_RegionExit[Self.E](self.take_override(), True)), _no_invoke))
            self.override = Optional(masked^)
            self.switched = True
            var invoke = self.head.invoke
            invoke(self.head.take_box(), self.address())
        else:
            self.head.take_box().take[_Restore[Self.E]]().enter(self, context)

    def finish_leaf(mut self):
        var step = self.leaf.value().take_step()
        self.leaf = None
        self.protected = step._protected_success
        self.put_outcome(step^._outcome())


def _publish[E: Movable & Deinitable](context: IOContext[E], budget: Int):
    """Return a run loop's unspent transitions to the root budget it shares."""
    if context._budget:
        ref shared = context._budget.value()[]
        shared.consumed += shared.remaining - budget
        shared.remaining = budget


def _loop_at[E: Movable & Deinitable](loop: MutOpaquePointer[_]) -> ref[loop.origin] _RunLoop[E]:
    # The run loop lends its own address; the engine fixes this type.
    return loop.unsafe_bitcast[_RunLoop[E]]()[]


def _box_step[V: Movable & Deinitable, E: Movable & Deinitable](var step: Step[V, E]) -> Step[_Erased, E]:
    """Box a step's success value; the caller's type fixes V for unboxing."""
    if not step._completed:
        return Step[_Erased, E].pending(step^._waiting())
    var protected = step._protected_success
    var outcome = step^._outcome()
    if outcome and outcome.value().is_ok():
        var boxed: Outcome[_Erased, E] = Optional(Result[_Erased, EffectFailure[E]](Ok(_Erased(outcome.take()._take_ok()))))
        return Step[_Erased, E]._make(Optional(boxed^), Wait(), protected)
    var failed = _failure_as[_Erased](outcome^)
    return Step[_Erased, E]._make(Optional(failed^), Wait(), protected)



@fieldwise_init
struct _FiberLoop[E: Movable & Deinitable](Machine):
    """A fiber's own run loop, polled through the slot of its task."""
    comptime Value = _Erased
    comptime Error = Self.E
    var loop: OwnedPointer[_RunLoop[Self.E]]

    def poll(mut self, context: IOContext[Self.E]) -> Step[_Erased, Self.E]:
        return self.loop[].run(context)


struct Fiber[T: Movable & Deinitable, E: Movable & Deinitable](Movable, ThreadTransferable, _RootBound):
    """The handle of an IO started with `start`, owned by the fiber that started it.

    The counterpart of Cats Effect's Fiber. Join it once to take its outcome, or
    cancel it. Dropping the handle neither stops nor detaches the child: its
    owner cancels and drains every live child before completing. A failure that
    is never joined goes to the runtime's reporter once the handle, or a join
    that did not take the outcome, is dropped; a success is destroyed.

    Parameters:
        T: The child's success value.
        E: The exact domain error the child shares with its owner.
    """
    var _claim: _Claim[Self.E]

    def __init__(out self, *, var _record: ArcPointer[_FiberRecord[Self.E]]):
        self._claim = _Claim[Self.E](_record^)

    def __init__(out self, *, var _claim: _Claim[Self.E]):
        self._claim = _claim^

    def _into_claim(deinit self) -> _Claim[Self.E]:
        """The right to the outcome, for a `Background` that joins it later."""
        return self._claim^

    def _take_outcome(deinit self) -> Outcome[_Erased, Self.E]:
        """Take the finished child's outcome; the same step consumes the claim."""
        return self._claim^.take()

    def join(deinit self) -> IO[Outcome[Self.T, Self.E], Self.E]:
        """Wait for the child and its cleanup to finish, then take its outcome.

        Returns:
            An IO producing the child's success, complete failure, or
            cancellation as an Outcome; it parks until the child completes.
        """
        return IO[_Delivery[Self.E], Self.E]._lifted(_Join[Self.E](self._claim^))._mapped(_Unwrap[Self.T, Self.E]())

    def join_with(deinit self, var fallback: IO[Self.T, Self.E]) -> IO[Self.T, Self.E]:
        """Join, continuing with a fallback if the child was canceled.

        Args:
            fallback: The IO to run instead of a cancellation-only outcome.

        Returns:
            An IO producing the child's value, failing with its errors, or
            running the fallback.
        """
        return self^.join()._bind(_Embed[Self.T, Self.E](fallback^))

    def join_with_never(deinit self) -> IO[Self.T, Self.E]:
        """Join; a canceled child leaves the joiner waiting until it is canceled.

        Returns:
            An IO producing the child's value or failing with its errors.
        """
        return self^.join_with(IO[Self.T, Self.E].never())

    def join_with_unit(deinit self) -> IO[NoneType, Self.E] where Self.T == NoneType:
        """Join a unit child; a canceled child produces unit.

        Returns:
            An IO producing unit or failing with the child's errors.
        """
        return rebind_var[IO[NoneType, Self.E]](self^.join_with(rebind_var[IO[Self.T, Self.E]](IO[NoneType, Self.E].pure(None))))

    def cancel(self) -> IO[NoneType, Self.E]:
        """Request cancellation and wait for the child to finish, without its result.

        The wait itself is not canceled, as in Cats Effect: it ends when the
        child and its cleanup finish.

        Returns:
            A unit IO completing after the child terminates.
        """
        return IO[NoneType, Self.E]._lifted(_CancelFiber[Self.E](self._claim.record.copy(), False))

    def request_cancel(self) -> IO[NoneType, Self.E]:
        """Request cancellation of the child without waiting.

        Returns:
            A unit IO completing at once.
        """
        return IO[NoneType, Self.E]._lifted(_RequestCancel[Self.E](self._claim.record.copy()))



struct Background[T: Movable & Deinitable, E: Movable & Deinitable](Movable, ThreadTransferable, _RootBound):
    """The handle of a fiber started by `IO.background`, owned by its `Resource`.

    Cats Effect's `background` hands its body an `F[Outcome]` it can run as
    often as it likes. Here `Resource.use` lends its value by borrow and an
    `IO` runs once, so the body gets this handle instead and builds joins from
    it. The resource cancels the fiber and waits for it on release.

    Parameters:
        T: The fiber's success value.
        E: The exact domain error the fiber shares with its owner.
    """
    var _record: ArcPointer[_FiberRecord[Self.E]]
    # The right to the outcome, taken by the first join that runs; locked, since
    # joins may run on two workers at once.
    var _claim: ArcPointer[_Cell[Optional[_Claim[Self.E]]]]

    def __init__(out self, *, var _fiber: Fiber[Self.T, Self.E]):
        var claim = _fiber^._into_claim()
        self._record = claim.record.copy()
        self._claim = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(Optional(claim^))))

    def join(self) -> IO[Outcome[Self.T, Self.E], Self.E]:
        """Wait for the fiber and its cleanup, then take its outcome.

        The outcome can be taken once: a second join that runs aborts, naming
        this call, as taking an outcome twice is a protocol violation.

        Returns:
            An IO producing the fiber's success, complete failure, or
            cancellation as an Outcome.
        """
        return IO[Outcome[Self.T, Self.E], Self.E]._deferred(_JoinBackground[Self.T, Self.E](self._claim.copy()))

    def cancel(self) -> IO[NoneType, Self.E]:
        """Request cancellation and wait for the fiber to finish, as `Fiber.cancel` does.

        Returns:
            A unit IO completing after the fiber terminates.
        """
        return IO[NoneType, Self.E]._lifted(_CancelFiber[Self.E](self._record.copy(), False))


struct _JoinBackground[T: Movable & Deinitable, E: Movable & Deinitable](OnceThunk):
    """Take a background fiber's claim when the join runs, then join as `Fiber.join` does."""
    var claim: ArcPointer[_Cell[Optional[_Claim[Self.E]]]]
    comptime Out = IO[Outcome[Self.T, Self.E], Self.E]
    comptime Error = Never

    def __init__(out self, var claim: ArcPointer[_Cell[Optional[_Claim[Self.E]]]]):
        self.claim = claim^

    def call_once(deinit self) -> Self.Out:
        var claim = Optional[_Claim[Self.E]]()
        var guard = _lock_cell(self.claim[])
        if guard.value():
            claim = Optional(guard.value().take())
        _ = guard^
        if not claim:
            abort("fp.effects: Background.join ran a second time; a background fiber's outcome is taken once")
        return Fiber[Self.T, Self.E](_claim=claim.take()).join()


struct _BackgroundPlan[T: Movable & Deinitable, E: Movable & Deinitable](ResourcePlan):
    """`IO.background`'s resource: start the fiber in the using program, then lend its handle.

    A fiber is drained when the program that started it ends, and an acquire
    runs as its own program, so `Resource.make(io.start(), ...)` would cancel
    the fiber as soon as it was acquired. Starting it in the program that runs
    the use keeps it alive for the body; the handle's resource then cancels it
    on release.
    """
    comptime Value = Background[Self.T, Self.E]
    comptime Error = Self.E
    comptime _Used[U: ScopedMachine] = IO[U.Value, Self.E]
    var program: IO[Self.T, Self.E]

    def __init__(out self, var program: IO[Self.T, Self.E]):
        self.program = program^

    def _use[U: ScopedMachine](deinit self, var body: U) -> IO[U.Value, Self.E]:
        return self.program^.start()._bind(_UseBackground[Self.T, Self.E, U](body^))


struct _UseBackground[T: Movable & Deinitable, E: Movable & Deinitable, U: ScopedMachine](OnceUnary):
    """Lend the started fiber's handle to the body; release cancels the fiber and waits for it."""
    var body: Self.U
    comptime Arg = Fiber[Self.T, Self.E]
    comptime Out = IO[Self.U.Value, Self.E]

    def __init__(out self, var body: Self.U):
        self.body = body^

    def call_once(deinit self, var fiber: Fiber[Self.T, Self.E]) -> Self.Out:
        var handle = IO[Background[Self.T, Self.E], Self.E].pure(Background[Self.T, Self.E](_fiber=fiber^))
        return Resource[Background[Self.T, Self.E], Self.E].make(handle^, _ReleaseBackground[Self.T, Self.E]())._use(self.body^)


struct _ReleaseBackground[T: Movable & Deinitable, E: Movable & Deinitable](BorrowCallable, Defaultable):
    """Release a background fiber: cancel it and wait for it."""
    comptime Payload = Background[Self.T, Self.E]
    comptime Result = IO[NoneType, Self.E]
    comptime Failure = Never

    def __init__(out self):
        pass

    def invoke(self, ref background: Background[Self.T, Self.E]) -> IO[NoneType, Self.E]:
        return background.cancel()


struct Ref[T: Movable & Deinitable](Copyable, ThreadTransferable):
    """A shared cell with serialized updates, including move-only state.

    The counterpart of Cats Effect's Ref, over the cell the synchronous
    `fp.effects.Ref` owns. Copies share the cell. Each operation is an IO that
    runs once, when reached: callbacks run under the cell's guard, must not
    reenter the same Ref, and never suspend, so an update is atomic with
    respect to other fibers. Raising updates are rejected because consuming
    the old state would lose it on failure. Callbacks must own their state, as
    for other IO callbacks.

    Parameters:
        T: The exact owned state type; callbacks cannot borrow it out of the cell.
    """
    var _source: _Ref[Self.T]

    def __init__(out self, var value: Self.T):
        """Allocate a shared cell holding the initial value.

        Args:
            value: The initial state, consumed.
        """
        self._source = _Ref[Self.T](value^)

    def get[E: Movable & Deinitable](self) -> IO[Self.T, E] where conforms_to(Self.T, Copyable):
        """Copy the current state.

        Parameters:
            E: The selected domain error of the returned IO.

        Returns:
            An IO yielding a copy; available only when T is Copyable.
        """
        return IO[Self.T, E]._lifted(_Once(self._source.get[E]()))

    def set[E: Movable & Deinitable](self, var value: Self.T) -> IO[NoneType, E]:
        """Replace the state, destroying the previous one.

        Parameters:
            E: The selected domain error of the returned IO.

        Args:
            value: The replacement, consumed into the unopened IO.

        Returns:
            A unit IO.
        """
        return IO[NoneType, E]._lifted(_Once(self._source.set[E](value^)))

    def get_and_set[E: Movable & Deinitable](self, var value: Self.T) -> IO[Self.T, E]:
        """Replace the state and transfer the previous one to the caller.

        Parameters:
            E: The selected domain error of the returned IO.

        Args:
            value: The replacement, consumed into the unopened IO.

        Returns:
            An IO yielding the previous state without copying it.
        """
        return IO[Self.T, E]._lifted(_Once(self._source.get_and_set[E](value^)))

    def update[F: UnaryContract & Movable & Deinitable, //, E: Movable & Deinitable](self, var function: F) -> IO[NoneType, E] where F.Arg == Self.T and F.Out == Self.T and F.Error == Never and _OnceUnaryAvailable[F] and _Admitted[F]:
        """Transform the state atomically.

        Parameters:
            F: An owned once-callable non-raising transformation from T to T.
            E: The selected domain error of the returned IO.

        Args:
            function: The transformation, consumed.

        Returns:
            A unit IO.
        """
        return IO[NoneType, E]._lifted(_Once(self._source.update[E](function^)))

    def update[E: Movable & Deinitable](self, function: def(var _NativeOwnedArg[Self.T]) thin -> Self.T) -> IO[NoneType, E]:
        """Transform the state atomically with a plain function; closures are rejected."""
        return self.update[E](NativeUnary[Self.T, Self.T, Never, def(var _NativeOwnedArg[Self.T]) thin -> Self.T, False](function))

    def modify[E: Movable & Deinitable, A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](self, var function: F) -> IO[A, E] where F.Arg == Self.T and F.Out == Tuple[Self.T, A] and F.Error == Never and _OnceUnaryAvailable[F] and _Admitted[F]:
        """Consume the state and replace it, returning a result, atomically.

        Parameters:
            E: The selected domain error of the returned IO.
            A: The owned result type.
            F: An owned once-callable non-raising transformation from T to (T, A).

        Args:
            function: The transformation, consumed.

        Returns:
            An IO yielding A after replacing the state.
        """
        return IO[A, E]._lifted(_Once(self._source.modify[E, A](function^)))

    def modify[E: Movable & Deinitable, A: Movable & Deinitable](self, function: def(var _NativeOwnedArg[Self.T]) thin -> Tuple[Self.T, A]) -> IO[A, E]:
        """Modify with a plain function; spell modify[E, A]. Closures are rejected."""
        return self.modify[E, A](NativeUnary[Self.T, Tuple[Self.T, A], Never, def(var _NativeOwnedArg[Self.T]) thin -> Tuple[Self.T, A], False](function))

    def get_and_update[F: UnaryContract & Movable & Deinitable, //, E: Movable & Deinitable](self, var function: F) -> IO[Self.T, E] where F.Arg == Self.T and F.Out == Self.T and F.Error == Never and _OnceUnaryAvailable[F] and conforms_to(Self.T, Copyable) and _Admitted[F]:
        """Transform the state atomically, yielding a copy of the previous state.

        Parameters:
            F: An owned once-callable non-raising transformation from T to T.
            E: The selected domain error of the returned IO.

        Args:
            function: The transformation, consumed.

        Returns:
            An IO yielding the state before the update; available only when T is Copyable.
        """
        return IO[Self.T, E]._lifted(_Once(self._source.get_and_update[E](function^)))

    def get_and_update[E: Movable & Deinitable](self, function: def(var _NativeOwnedArg[Self.T]) thin -> Self.T) -> IO[Self.T, E] where conforms_to(Self.T, Copyable):
        """Transform with a plain function, yielding the previous state; closures are rejected."""
        return self.get_and_update[E](NativeUnary[Self.T, Self.T, Never, def(var _NativeOwnedArg[Self.T]) thin -> Self.T, False](function))

    def update_and_get[F: UnaryContract & Movable & Deinitable, //, E: Movable & Deinitable](self, var function: F) -> IO[Self.T, E] where F.Arg == Self.T and F.Out == Self.T and F.Error == Never and _OnceUnaryAvailable[F] and conforms_to(Self.T, Copyable) and _Admitted[F]:
        """Transform the state atomically, yielding a copy of the next state.

        Parameters:
            F: An owned once-callable non-raising transformation from T to T.
            E: The selected domain error of the returned IO.

        Args:
            function: The transformation, consumed.

        Returns:
            An IO yielding the state after the update; available only when T is Copyable.
        """
        return IO[Self.T, E]._lifted(_Once(self._source.update_and_get[E](function^)))

    def update_and_get[E: Movable & Deinitable](self, function: def(var _NativeOwnedArg[Self.T]) thin -> Self.T) -> IO[Self.T, E] where conforms_to(Self.T, Copyable):
        """Transform with a plain function, yielding the next state; closures are rejected."""
        return self.update_and_get[E](NativeUnary[Self.T, Self.T, Never, def(var _NativeOwnedArg[Self.T]) thin -> Self.T, False](function))

    def inspect[F: BorrowCallContract & Movable & Deinitable, //, E: Movable & Deinitable](self, var function: F) -> IO[F.Result, E] where F.Payload == Self.T and _ErrorCompatible[E, F.Failure] and _OnceBorrowAvailable[F] and _Admitted[F]:
        """Borrow the state once under the guard and return an owned result.

        Parameters:
            F: An owned borrowing callable whose result does not borrow the state.
            E: The selected domain error; the callable's error must be E or Never.

        Args:
            function: The observation, consumed.

        Returns:
            An IO yielding the observation, or failing with its error.
        """
        return IO[F.Result, E]._lifted(_Once(self._source.inspect[E](function^)))

    def inspect[A: Movable & Deinitable, //, E: Movable & Deinitable](self, function: def(Self.T) thin -> A) -> IO[A, E]:
        """Observe the state with a plain borrowing function; closures are rejected."""
        return self.inspect[E](_NativeBorrow[Self.T, A, Never, def(Self.T) thin -> A, False](function))

    def inspect[A: Movable & Deinitable, X: Movable & Deinitable, //, E: Movable & Deinitable](self, function: def(Self.T) raises X thin -> A) -> IO[A, E] where _ErrorCompatible[E, X]:
        """Observe the state with a plain borrowing function, keeping its compatible error."""
        return self.inspect[E](_NativeBorrow[Self.T, A, X, def(Self.T) raises X thin -> A, True](function))


@fieldwise_init
struct _NewRef[T: Movable & Deinitable](OnceThunk):
    """Allocate a Ref when the program reaches it."""
    var value: Self.T
    comptime Out = Ref[Self.T]
    comptime Error = Never

    def call_once(deinit self) -> Ref[Self.T]:
        return Ref[Self.T](self.value^)


struct _NewDeferred[T: Copyable & Deinitable](OnceThunk, Defaultable):
    """Allocate a Deferred when the program reaches it."""
    comptime Out = Deferred[Self.T]
    comptime Error = Never

    def __init__(out self):
        pass

    def call_once(deinit self) -> Deferred[Self.T]:
        return Deferred[Self.T]()


struct Deferred[T: Copyable & Deinitable](Copyable, ThreadTransferable):
    """Shared single-assignment value; waiting readers receive owned copies.

    Parameters:
        T: The stored value, copied for successful reads.
    """
    var _source: _Deferred[Self.T]

    def __init__(out self):
        self._source = _Deferred[Self.T]()

    def complete[E: Movable & Deinitable](self, var value: Self.T) -> IO[Bool, E]:
        """Attempt single assignment when the recipe executes.

        Parameters:
            E: The selected domain error of the returned recipe.

        Args:
            value: The owned value, consumed into the unopened recipe.

        Returns:
            An IO yielding whether this assignment won; later assignments leave the stored value intact."""
        return IO[Bool, E]._lifted(_Once(self._source.complete[E](value^)))

    def try_get[E: Movable & Deinitable](self) -> IO[Optional[Self.T], E]:
        """Read the current assignment without waiting.

        Parameters:
            E: The selected domain error of the returned recipe.

        Returns:
            An IO yielding an owned optional copy of the value."""
        return IO[Optional[Self.T], E]._lifted(_Once(self._source.try_get[E]()))

    def get[E: Movable & Deinitable](self) -> IO[Self.T, E]:
        """Wait cooperatively for assignment, unless canceled.

        Parameters:
            E: The selected domain error of the returned recipe.

        Returns:
            An IO yielding an owned copy after assignment."""
        return IO[Self.T, E]._lifted(_Await[Self.T, _RefInspect[Optional[Self.T], E, _Copy[Optional[Self.T]]]](self._source.get[E]()._into_attempt(), False))


@fieldwise_init
struct _Embed[T: Movable & Deinitable, E: Movable & Deinitable](OnceUnary):
    """Cats Effect's Outcome.embed: a value, a failure, or the fallback."""
    comptime Arg = Outcome[Self.T, Self.E]
    comptime Out = IO[Self.T, Self.E]
    var fallback: IO[Self.T, Self.E]

    def call_once(deinit self, var outcome: Outcome[Self.T, Self.E]) -> IO[Self.T, Self.E]:
        if not outcome:
            return self.fallback^
        var result = outcome.take()
        if result.is_ok():
            return IO[Self.T, Self.E].pure(result^._take_ok())
        # The child's cancellation flag belongs to the child, not the joiner.
        var failure = result^._take_err()
        failure.canceled = False
        return IO[Self.T, Self.E]._failed(failure^)


struct _Boxed[P: Machine, E: Movable & Deinitable](Machine):
    """Present a typed leaf to the run loop with its success value boxed."""
    comptime Value = _Erased
    comptime Error = Self.E
    var program: Self.P

    def __init__(out self, var program: Self.P):
        self.program = program^

    def poll(mut self, context: IOContext[Self.E]) -> Step[_Erased, Self.E]:
        comptime assert Self.P.Error == Self.E
        return _box_step(rebind_var[Step[Self.P.Value, Self.E]](self.program.poll(rebind[IOContext[Self.P.Error]](context))))


struct _Unbox[V: Movable & Deinitable](OnceUnary, Defaultable):
    """Take a value boxed by a function the same V specialized."""
    comptime Arg = _Erased
    comptime Out = Self.V

    def __init__(out self):
        pass

    def call_once(deinit self, var boxed: _Erased) -> Self.V:
        return boxed^.take[Self.V]()


# Erasure drops the origin a borrowed callback view relies on. IO admits owned
# callbacks only; callable state that embeds a borrow remains the caller's
# documented precondition, since Mojo 1.2 cannot check it.
comptime _Admitted[F: AnyType] = not conforms_to(F, _BorrowedView)

comptime _IsIO[V: Movable & Deinitable, E: Movable & Deinitable] = (V == IO[downcast[V, Machine].Value, E]) if conforms_to(V, Machine) else False

# Callback admission shared by IO's methods and its family. Exact argument
# equality stays with each operation, as the family protocols require.
comptime _Maps[E: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _OnceUnaryAvailable[F] and _ErrorCompatible[E, F.Error] and _Admitted[F]
comptime _Binds[E: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _Maps[E, F] and _IsIO[F.Out, E]
comptime _Defers[E: Movable & Deinitable, F: ThunkContract & Movable & Deinitable] = _OnceThunkAvailable[F] and _ErrorCompatible[E, F.Error] and _Admitted[F] and _IsIO[F.Out, E]


struct IO[T: Movable & Deinitable, E: Movable & Deinitable](Machine, _FamilyCarrier):
    """An asynchronous program producing T or failing with the exact domain error E.

    Building an IO runs nothing. A value runs once, when a host drives it;
    repeated work builds a fresh IO. Sequencing, recovery, and finalizers run
    iteratively in constant native stack, and an unopened IO may be dropped.
    Callbacks stored in an IO must own their state: plain functions and owned
    library callables are admitted, capturing closures and borrowed callback
    views are rejected.

    Parameters:
        T: The owned success value, including its origins.
        E: The exact domain error shared by every IO in one chain.
    """
    comptime Family = Async[Self.E]
    comptime Value = Self.T
    comptime Error = Self.E
    var _program: _Program[Self.E]
    var _loop: MaybeUninit[OwnedPointer[_RunLoop[Self.E]]]
    var _entered: Bool

    def __init__(out self, *, var _program: _Program[Self.E]):
        self._program = _program^
        self._loop = MaybeUninit[OwnedPointer[_RunLoop[Self.E]]]()
        self._entered = False

    def __deinit__(deinit self):
        if self._entered:
            self._loop^.unsafe_deinit()
        else:
            self._loop^.unsafe_forget()

    def _into_program(deinit self) -> _Program[Self.E]:
        if self._entered:
            abort("an entered IO cannot be composed")
        self._loop^.unsafe_forget()
        return self._program^

    @staticmethod
    def pure(var value: Self.T) -> Self:
        """Own an evaluated value.

        Args:
            value: The value, consumed once.

        Returns:
            An IO producing the value.
        """
        return Self(_program=_Program[Self.E](_Head[Self.E](_PURE, _Erased(value^))))

    @staticmethod
    def raise_error(var error: Self.E) -> Self:
        """Fail with one domain error.

        Args:
            error: The error, consumed once.

        Returns:
            An IO failing with an uncanceled EffectFailure holding the error.
        """
        return Self(_program=_Program[Self.E](_Head[Self.E](_FAIL, _Erased(EffectFailure[Self.E](NonEmptyList(error^), False)))))

    @staticmethod
    def _failed(var failure: EffectFailure[Self.E]) -> Self:
        return Self(_program=_Program[Self.E](_Head[Self.E](_FAIL, _Erased(failure^))))

    # Public operations state admission in their signatures and delegate to
    # private forms, which generic code calls after its own checks.
    @staticmethod
    def lift[P: Machine](var machine: P) -> Self where P.Value == Self.T and P.Error == Self.E:
        """Run a custom machine as one step of an IO.

        The IO keeps origins only through T and E, so the machine must own its
        state, or borrow only what T or E already names.

        Parameters:
            P: A machine with this IO's value and error types.

        Args:
            machine: The unopened machine, consumed once.

        Returns:
            An IO that polls the machine until it completes.
        """
        return Self._lifted(machine^)

    @staticmethod
    def _lifted[P: Machine](var machine: P) -> Self:
        comptime assert P.Value == Self.T and P.Error == Self.E
        return Self(_program=_Program[Self.E](_Head[Self.E](_LEAF, _Erased(_Leaf[Self.E](_Boxed[P, Self.E](machine^))))))

    @staticmethod
    def delay[F: ThunkContract & Movable & Deinitable](var function: F) -> Self where _DelayValue[F.Out] == Self.T and _OnceThunkAvailable[F] and _ErrorCompatible[Self.E, F.Error] and _Admitted[F]:
        """Evaluate a synchronous function when the IO reaches it.

        Use defer when the function builds an IO.

        Parameters:
            F: An owned once-callable producing T, or no value when T is
                NoneType, with error E or none.

        Args:
            function: The function, consumed; it runs once, when reached.

        Returns:
            An IO producing the function's result; its error becomes the failure.
        """
        return Self._deferred(_Delay[F, Self.E](function^))

    # The result type is inferred, as for native delay elsewhere: a stored thin
    # pointer cannot convert to a signature spelled with Self.T.
    @staticmethod
    def delay[R: Movable & Deinitable, //](function: def() thin -> R) -> Self where R == Self.T and not conforms_to(R, RegisterPassable):
        """Evaluate a native function when the IO reaches it."""
        return Self._deferred(_Delay[_NativeThunk[R, Never, def() thin -> R, False], Self.E](_NativeThunk[R, Never, def() thin -> R, False](function)))

    @staticmethod
    def delay[R: RegisterPassable & Deinitable, //](function: def() thin -> R) -> Self where R == Self.T:
        """Evaluate a native function when the IO reaches it."""
        return Self._deferred(_Delay[_NativeThunk[R, Never, def() thin -> R, False], Self.E](_NativeThunk[R, Never, def() thin -> R, False](function)))

    @staticmethod
    def delay[R: Movable & Deinitable, X: Movable & Deinitable, //](function: def() raises X thin -> R) -> Self where R == Self.T and _ErrorCompatible[Self.E, X] and not conforms_to(R, RegisterPassable):
        """Evaluate a raising native function; its error becomes the failure."""
        return Self._deferred(_Delay[_NativeThunk[R, X, def() raises X thin -> R, True], Self.E](_NativeThunk[R, X, def() raises X thin -> R, True](function)))

    @staticmethod
    def delay(function: def() thin) -> Self where Self.T == NoneType:
        """Evaluate a native function with no return value; the IO produces None."""
        return Self._deferred(_Delay[_NativeThunk[type_of(None), Never, def() thin, False], Self.E](_NativeThunk[type_of(None), Never, def() thin, False](function)))

    @staticmethod
    def delay[X: Movable & Deinitable, //](function: def() raises X thin) -> Self where Self.T == NoneType and _ErrorCompatible[Self.E, X]:
        """Evaluate a raising native function with no return value; its error becomes the failure."""
        return Self._deferred(_Delay[_NativeThunk[type_of(None), X, def() raises X thin, True], Self.E](_NativeThunk[type_of(None), X, def() raises X thin, True](function)))

    @staticmethod
    def delay[R: RegisterPassable & Deinitable, X: Movable & Deinitable, //](function: def() raises X thin -> R) -> Self where R == Self.T and _ErrorCompatible[Self.E, X]:
        """Evaluate a raising native function; its error becomes the failure."""
        return Self._deferred(_Delay[_NativeThunk[R, X, def() raises X thin -> R, True], Self.E](_NativeThunk[R, X, def() raises X thin -> R, True](function)))

    @staticmethod
    def defer[F: ThunkContract & Movable & Deinitable](var factory: F) -> Self where _Defers[Self.E, F] and F.Out == Self:
        """Build the IO when it is reached, so recursive programs build lazily.

        Parameters:
            F: An owned once-callable returning this IO type, with error E or none.

        Args:
            factory: The factory, consumed; it runs once, when reached.

        Returns:
            An IO running the program the factory builds.
        """
        return Self._deferred(factory^)

    @staticmethod
    def defer(factory: def() thin -> Self) -> Self:
        """Build the IO with a native function when it is reached."""
        return Self._deferred(_NativeThunk[Self, Never, def() thin -> Self, False](factory))

    @staticmethod
    def defer[X: Movable & Deinitable, //](factory: def() raises X thin -> Self) -> Self where _ErrorCompatible[Self.E, X]:
        """Build the IO with a raising native function; its error becomes the failure."""
        return Self._deferred(_NativeThunk[Self, X, def() raises X thin -> Self, True](factory))

    @staticmethod
    def _deferred[F: ThunkContract & Movable & Deinitable](var factory: F) -> Self:
        def invoke(var callable: _Erased, loop: MutOpaquePointer[_]):
            comptime assert _Defers[Self.E, F] and F.Out == Self
            ref run = _loop_at[Self.E](loop)
            # Callbacks install their result directly: a captured Result holding an
            # IO is built and unwrapped out of line when the compiler does not inline it.
            comptime if F.Error == Never:
                rebind_var[Self](_thunk_once_as[Never](callable^.take[F]()))._into_program().install_into(run)
            else:
                try:
                    rebind_var[Self](_thunk_once_as[Self.E](callable^.take[F]()))._into_program().install_into(run)
                except error:
                    run.set_failure(EffectFailure[Self.E](NonEmptyList(error^), False))

        comptime assert _Defers[Self.E, F] and F.Out == Self
        return Self(_program=_Program[Self.E](_Head[Self.E](_DEFER, _Erased(factory^), invoke)))

    def flat_map[F: UnaryContract & Movable & Deinitable](deinit self, var f: F) -> IO[downcast[F.Out, Machine].Value, Self.E] where F.Arg == Self.T and _Binds[Self.E, F]:
        """Continue with the IO a callback builds from the success value.

        Parameters:
            F: An owned once-callable from T to an IO with error E.

        Args:
            f: The callback, consumed; failure and cancellation skip it.

        Returns:
            An IO running both in sequence; the callback's error becomes the failure.
        """
        return self^._bind(f^)

    def flat_map[U: Movable & Deinitable, //](deinit self, f: def(var _NativeOwnedArg[Self.T]) thin -> IO[U, Self.E]) -> IO[U, Self.E]:
        """Continue with the IO a native function builds from the success value."""
        return self^._bind(NativeUnary[Self.T, IO[U, Self.E], Never, def(var _NativeOwnedArg[Self.T]) thin -> IO[U, Self.E], False](f))

    def flat_map[U: Movable & Deinitable, X: Movable & Deinitable, //](deinit self, f: def(var _NativeOwnedArg[Self.T]) raises X thin -> IO[U, Self.E]) -> IO[U, Self.E] where _ErrorCompatible[Self.E, X]:
        """Continue with a raising native function; its error becomes the failure."""
        return self^._bind(NativeUnary[Self.T, IO[U, Self.E], X, def(var _NativeOwnedArg[Self.T]) raises X thin -> IO[U, Self.E], True](f))

    def _bind[F: UnaryContract & Movable & Deinitable](deinit self, var f: F) -> IO[downcast[F.Out, Machine].Value, Self.E]:
        comptime U = downcast[F.Out, Machine].Value

        def invoke(var callable: _Erased, loop: MutOpaquePointer[_]):
            comptime assert F.Arg == Self.T and _Binds[Self.E, F]
            ref run = _loop_at[Self.E](loop)
            var argument = run.take_value().take[Self.T]()
            comptime if F.Error == Never:
                var next = _unary_once_as[Never](callable^.take[F](), rebind_var[F.Arg](argument^))
                rebind_var[IO[U, Self.E]](next^)._into_program().install_into(run)
            else:
                try:
                    var next = _unary_once_as[Self.E](callable^.take[F](), rebind_var[F.Arg](argument^))
                    rebind_var[IO[U, Self.E]](next^)._into_program().install_into(run)
                except error:
                    run.set_failure(EffectFailure[Self.E](NonEmptyList(error^), False))

        comptime assert F.Arg == Self.T and _Binds[Self.E, F]
        var program = self^._into_program()
        program.frames.append(_Frame(_BIND, _Erased(f^), invoke))
        return IO[U, Self.E](_program=program^)

    def map[F: UnaryContract & Movable & Deinitable](deinit self, var f: F) -> IO[F.Out, Self.E] where F.Arg == Self.T and _Maps[Self.E, F]:
        """Apply a callback to the success value.

        Parameters:
            F: An owned once-callable from T, with error E or none.

        Args:
            f: The callback, consumed; failure and cancellation skip it.

        Returns:
            An IO of the callback's result; its error becomes the failure.
        """
        return self^._mapped(f^)

    def map[R: Movable & Deinitable, //](deinit self, f: def(var _NativeOwnedArg[Self.T]) thin -> R) -> IO[R, Self.E] where not conforms_to(R, RegisterPassable):
        """Apply a native function to the success value."""
        return self^._mapped(NativeUnary[Self.T, R, Never, def(var _NativeOwnedArg[Self.T]) thin -> R, False](f))

    def map[R: RegisterPassable & Deinitable, //](deinit self, f: def(var _NativeOwnedArg[Self.T]) thin -> R) -> IO[R, Self.E]:
        """Apply a native function to the success value."""
        return self^._mapped(NativeUnary[Self.T, R, Never, def(var _NativeOwnedArg[Self.T]) thin -> R, False](f))

    def map[R: Movable & Deinitable, X: Movable & Deinitable, //](deinit self, f: def(var _NativeOwnedArg[Self.T]) raises X thin -> R) -> IO[R, Self.E] where _ErrorCompatible[Self.E, X] and not conforms_to(R, RegisterPassable):
        """Apply a raising native function; its error becomes the failure."""
        return self^._mapped(NativeUnary[Self.T, R, X, def(var _NativeOwnedArg[Self.T]) raises X thin -> R, True](f))

    def map[R: RegisterPassable & Deinitable, X: Movable & Deinitable, //](deinit self, f: def(var _NativeOwnedArg[Self.T]) raises X thin -> R) -> IO[R, Self.E] where _ErrorCompatible[Self.E, X]:
        """Apply a raising native function; its error becomes the failure."""
        return self^._mapped(NativeUnary[Self.T, R, X, def(var _NativeOwnedArg[Self.T]) raises X thin -> R, True](f))

    def _mapped[F: UnaryContract & Movable & Deinitable](deinit self, var f: F) -> IO[F.Out, Self.E]:
        def invoke(var callable: _Erased, loop: MutOpaquePointer[_]):
            comptime assert F.Arg == Self.T and _Maps[Self.E, F]
            ref run = _loop_at[Self.E](loop)
            var argument = run.take_value().take[Self.T]()
            comptime if F.Error == Never:
                run.set_value(_Erased(_unary_once_as[Never](callable^.take[F](), rebind_var[F.Arg](argument^))))
            else:
                try:
                    run.set_value(_Erased(_unary_once_as[Self.E](callable^.take[F](), rebind_var[F.Arg](argument^))))
                except error:
                    run.set_failure(EffectFailure[Self.E](NonEmptyList(error^), False))

        comptime assert F.Arg == Self.T and _Maps[Self.E, F]
        var program = self^._into_program()
        program.frames.append(_Frame(_BIND, _Erased(f^), invoke))
        return IO[F.Out, Self.E](_program=program^)

    def handle_error_with[H: UnaryContract & Movable & Deinitable](deinit self, var handler: H) -> Self where H.Arg == EffectFailure[Self.E] and _Maps[Self.E, H] and H.Out == Self:
        """Recover an ordinary failure with the IO a handler builds.

        Parameters:
            H: An owned once-callable from EffectFailure[E] to this IO type.

        Args:
            handler: The handler, consumed; success and failures marked canceled skip it.

        Returns:
            An IO with the original success or the handler's program.
        """
        return self^._recover(handler^)

    def handle_error_with(deinit self, handler: def(var EffectFailure[Self.E]) thin -> Self) -> Self:
        """Recover an ordinary failure with a native handler."""
        return self^._recover(NativeUnary[EffectFailure[Self.E], Self, Never, def(var EffectFailure[Self.E]) thin -> Self, False](handler))

    def handle_error_with[X: Movable & Deinitable, //](deinit self, handler: def(var EffectFailure[Self.E]) raises X thin -> Self) -> Self where _ErrorCompatible[Self.E, X]:
        """Recover with a raising native handler; its error replaces the failure."""
        return self^._recover(NativeUnary[EffectFailure[Self.E], Self, X, def(var EffectFailure[Self.E]) raises X thin -> Self, True](handler))

    def attempt(deinit self) -> IO[Result[Self.T, EffectFailure[Self.E]], Self.E]:
        """Materialize success or an ordinary failure as a Result.

        Returns:
            An IO of Result[T, EffectFailure[E]]. Cancellation and failures
            marked canceled stay terminal.
        """
        return rebind_var[IO[Result[Self.T, EffectFailure[Self.E]], Self.E]](_Materialize[Async[Self.E], Self].apply[Never](self^))

    def _recover[H: UnaryContract & Movable & Deinitable](deinit self, var handler: H) -> Self:
        def invoke(var callable: _Erased, loop: MutOpaquePointer[_]):
            comptime assert H.Arg == EffectFailure[Self.E] and _Maps[Self.E, H] and H.Out == Self
            ref run = _loop_at[Self.E](loop)
            var failure = run.failure.take()
            comptime if H.Error == Never:
                rebind_var[Self](_unary_once_as[Never](callable^.take[H](), rebind_var[H.Arg](failure^)))._into_program().install_into(run)
            else:
                try:
                    rebind_var[Self](_unary_once_as[Self.E](callable^.take[H](), rebind_var[H.Arg](failure^)))._into_program().install_into(run)
                except error:
                    run.set_failure(EffectFailure[Self.E](NonEmptyList(error^), False))

        comptime assert H.Arg == EffectFailure[Self.E] and _Maps[Self.E, H] and H.Out == Self
        var program = self^._into_program()
        program.frames.append(_Frame(_RECOVER, _Erased(handler^), invoke))
        return Self(_program=program^)

    def _finalized(deinit self, var finalizer: _Finalizer[Self.E]) -> Self:
        var program = self^._into_program()
        program.frames.append(_Frame(_FINALIZE, _Erased(finalizer^), _no_invoke))
        return Self(_program=program^)

    def guarantee(deinit self, var finalizer: IO[NoneType, Self.E]) -> Self:
        """Run a finalizer masked after every outcome.

        Args:
            finalizer: The cleanup, consumed; it runs once after the body.

        Returns:
            An IO with the body's outcome; body errors precede cleanup errors.
        """
        return self^._finalized(_Finalizer[Self.E](False, Optional(finalizer^._into_program()), _Erased(), _no_cleanup[Self.E]))

    def on_cancel(deinit self, var finalizer: IO[NoneType, Self.E]) -> Self:
        """Run a finalizer masked only when the body observed cancellation.

        Args:
            finalizer: The cleanup, consumed; dropped unopened otherwise.

        Returns:
            An IO with the body's outcome.
        """
        return self^._finalized(_Finalizer[Self.E](True, Optional(finalizer^._into_program()), _Erased(), _no_cleanup[Self.E]))

    def guarantee_case[F: BorrowCallContract & Movable & Deinitable](deinit self, var factory: F) -> Self where F.Payload == ExitCase[Self.E] and F.Result == IO[NoneType, Self.E] and _OnceBorrowAvailable[F] and _ErrorCompatible[Self.E, F.Failure] and _Admitted[F]:
        """Build a finalizer from the body's exact exit, then run it masked.

        Parameters:
            F: An owned once-callable borrowing ExitCase[E] and returning IO[NoneType, E].

        Args:
            factory: The factory, consumed; it borrows the exit only while building.

        Returns:
            An IO with the body's outcome; body errors precede cleanup errors.
        """
        return self^._guarantee_case(factory^)

    def _guarantee_case[F: BorrowCallContract & Movable & Deinitable](deinit self, var factory: F) -> Self:
        def build(var callable: _Erased, exit: ExitCase[Self.E]) -> _Program[Self.E]:
            comptime assert F.Payload == ExitCase[Self.E] and F.Result == IO[NoneType, Self.E] and _OnceBorrowAvailable[F] and _ErrorCompatible[Self.E, F.Failure]
            comptime if F.Failure == Never:
                return rebind_var[IO[NoneType, Self.E]](_borrow_once_as[Never](exit, callable^.take[F]()))._into_program()
            else:
                try:
                    return rebind_var[IO[NoneType, Self.E]](_borrow_once_as[Self.E](exit, callable^.take[F]()))._into_program()
                except error:
                    return _Program[Self.E](_Head[Self.E](_FAIL, _Erased(EffectFailure[Self.E](NonEmptyList(error^), False))))

        return self^._finalized(_Finalizer[Self.E](False, None, _Erased(factory^), build))

    @staticmethod
    def uncancelable[F: UnaryContract & Movable & Deinitable](var factory: F) -> Self where F.Arg == Poll[Self.E] and F.Out == Self and _Maps[Self.E, F]:
        """Build and run a program masked; its Poll restores the outer state.

        Parameters:
            F: An owned once-callable from Poll[E] to this IO type.

        Args:
            factory: The factory, consumed; it runs once, when reached.

        Returns:
            An IO whose region observes no cancellation except through Poll.
        """
        return Self._uncancelable(factory^)

    @staticmethod
    def _uncancelable[F: UnaryContract & Movable & Deinitable](var factory: F) -> Self:
        def invoke(var callable: _Erased, loop: MutOpaquePointer[_]):
            comptime assert F.Arg == Poll[Self.E] and F.Out == Self and _Maps[Self.E, F]
            ref run = _loop_at[Self.E](loop)
            var poll = run.poll.take()
            comptime if F.Error == Never:
                rebind_var[Self](_unary_once_as[Never](callable^.take[F](), rebind_var[F.Arg](poll^)))._into_program().install_into(run)
            else:
                try:
                    rebind_var[Self](_unary_once_as[Self.E](callable^.take[F](), rebind_var[F.Arg](poll^)))._into_program().install_into(run)
                except error:
                    run.set_failure(EffectFailure[Self.E](NonEmptyList(error^), False))

        return Self(_program=_Program[Self.E](_Head[Self.E](_MASK, _Erased(factory^), invoke)))

    @staticmethod
    def uncancelable(factory: def(var Poll[Self.E]) thin -> Self) -> Self:
        """Build and run a program masked with a native factory."""
        return Self.uncancelable(NativeUnary[Poll[Self.E], Self, Never, def(var Poll[Self.E]) thin -> Self, False](factory))

    def restore(deinit self, poll: Poll[Self.E]) -> Self:
        """Run this program with the cancellation state outside poll's region.

        Args:
            poll: The handle an uncancelable factory received.

        Returns:
            An IO that observes cancellation as it would outside the region.
        """
        return Self(_program=_Program[Self.E](_Head[Self.E](_RESTORE, _Erased(_Restore[Self.E](poll.copy(), self^._into_program())))))

    @staticmethod
    def `async`[F: UnaryContract & Movable & Deinitable](var register: F, var withdrawal: IO[NoneType, Self.E]) -> Self where F.Arg == Completion[Self.T, Self.E] and _CallbackUnit[F.Out] and _Maps[Self.E, F]:
        """Register with an external source that completes this IO once.

        Declared with backticks because async is a Mojo keyword; call it as
        `IO[T, E].async(...)`.

        Parameters:
            F: An owned once-callable receiving Completion[T, E] and returning no value.

        Args:
            register: The registration, run once when reached.
            withdrawal: Runs masked after every entered registration.

        Returns:
            An IO settling with the completion, then the withdrawal's errors.
        """
        return Self._lifted(_Callback[F, IO[NoneType, Self.E]](register^, withdrawal^))

    @staticmethod
    def `async`(register: def(var Completion[Self.T, Self.E]) thin, var withdrawal: IO[NoneType, Self.E]) -> Self:
        """Register a native function with an external source."""
        return Self.`async`(NativeUnary[Completion[Self.T, Self.E], type_of(None), Never, def(var Completion[Self.T, Self.E]) thin, False](register), withdrawal^)

    @staticmethod
    def async_[F: UnaryContract & Movable & Deinitable](var register: F) -> Self where F.Arg == Completion[Self.T, Self.E] and _CallbackUnit[F.Out] and _Maps[Self.E, F]:
        """Register with an external source that needs no withdrawal.

        Parameters:
            F: An owned once-callable receiving Completion[T, E] and returning no value.

        Args:
            register: The registration, run once when reached.

        Returns:
            An IO settling with the completion.
        """
        var unit: NoneType = None
        return Self.`async`(register^, IO[NoneType, Self.E].pure(unit))

    @staticmethod
    def async_(register: def(var Completion[Self.T, Self.E]) thin) -> Self:
        """Register a native function that needs no withdrawal."""
        return Self.async_(NativeUnary[Completion[Self.T, Self.E], type_of(None), Never, def(var Completion[Self.T, Self.E]) thin, False](register))

    @staticmethod
    def blocking[F: ThunkContract & Movable & Deinitable](var function: F) -> Self where _DelayValue[F.Out] == Self.T and _OnceThunkAvailable[F] and _ErrorCompatible[Self.E, F.Error] and _Admitted[F]:
        """Run a blocking function on the root's blocking pool when the IO reaches it.

        The fiber suspends while a pool worker runs the function, so other
        fibers keep running; it resumes with the function's result or error.
        Like Cats Effect's `blocking`, the call cannot be canceled: a
        cancellation or timeout waits for the function to return. Mojo has no
        Send or Sync proof: the caller asserts that the function, its result
        and its error may move to, be used on, and be destroyed on another
        thread. Use interruptible for a function that can stop early.

        Parameters:
            F: An owned once-callable producing T, or no value when T is
                NoneType, with error E or none.

        Args:
            function: The function, consumed; it runs once, on a pool worker.

        Returns:
            An IO producing the function's result; its error becomes the failure.
        """
        return Self._blocking(function^)

    # Every overload shares this body; the native ones cannot restate the
    # generic overload's constraints on their adapter types.
    @staticmethod
    def _blocking[F: ThunkContract & Movable & Deinitable](var function: F) -> Self:
        comptime assert _DelayValue[F.Out] == Self.T and _ErrorCompatible[Self.E, F.Error]
        return rebind_var[Self](IO[_RootBlocking, Self.E]._lifted(_CurrentBlocking[Self.E]()).flat_map(_StartBlocking[F, Self.E](function^)))

    @staticmethod
    def blocking[R: Movable & Deinitable, //](function: def() thin -> R) -> Self where R == Self.T and not conforms_to(R, RegisterPassable):
        """Run a native blocking function on the root's blocking pool."""
        return Self._blocking(_NativeThunk[R, Never, def() thin -> R, False](function))

    @staticmethod
    def blocking[R: RegisterPassable & Deinitable, //](function: def() thin -> R) -> Self where R == Self.T:
        """Run a native blocking function on the root's blocking pool."""
        return Self._blocking(_NativeThunk[R, Never, def() thin -> R, False](function))

    @staticmethod
    def blocking[R: Movable & Deinitable, X: Movable & Deinitable, //](function: def() raises X thin -> R) -> Self where R == Self.T and _ErrorCompatible[Self.E, X] and not conforms_to(R, RegisterPassable):
        """Run a raising native blocking function; its error becomes the failure."""
        return Self._blocking(_NativeThunk[R, X, def() raises X thin -> R, True](function))

    @staticmethod
    def blocking(function: def() thin) -> Self where Self.T == NoneType:
        """Run a native blocking function with no return value; the IO produces None."""
        return Self._blocking(_NativeThunk[type_of(None), Never, def() thin, False](function))

    @staticmethod
    def blocking[X: Movable & Deinitable, //](function: def() raises X thin) -> Self where Self.T == NoneType and _ErrorCompatible[Self.E, X]:
        """Run a raising native blocking function with no return value; its error becomes the failure."""
        return Self._blocking(_NativeThunk[type_of(None), X, def() raises X thin, True](function))

    @staticmethod
    def blocking[R: RegisterPassable & Deinitable, X: Movable & Deinitable, //](function: def() raises X thin -> R) -> Self where R == Self.T and _ErrorCompatible[Self.E, X]:
        """Run a raising native blocking function; its error becomes the failure."""
        return Self._blocking(_NativeThunk[R, X, def() raises X thin -> R, True](function))

    @staticmethod
    def interruptible[F: BorrowCallContract & Movable & Deinitable](var function: F) -> Self where F.Payload == Interruption and F.Result == Self.T and _OnceBorrowAvailable[F] and _ErrorCompatible[Self.E, F.Failure] and _Admitted[F]:
        """Run a blocking function that can stop early, on the root's blocking pool.

        The function borrows an Interruption handle for the call. On
        cancellation the handle reports the request, which stays visible, and
        cancellation completes when the function returns; its late result is
        then rejected and destroyed on the worker. No signal is sent, as in
        Cats Effect on Scala Native: a function blocked outside the handle is
        not woken. The caller asserts that the function, its result and its
        error may move to, be used on, and be destroyed on another thread.

        Parameters:
            F: An owned once-callable borrowing an Interruption and producing
                T, with error E or none.

        Args:
            function: The function, consumed; it runs once, on a pool worker.

        Returns:
            An IO producing the function's result, or canceled after it returns.
        """
        return Self._interruptible(function^)

    @staticmethod
    def _interruptible[F: BorrowCallContract & Movable & Deinitable](var function: F) -> Self:
        comptime assert F.Payload == Interruption and F.Result == Self.T and _ErrorCompatible[Self.E, F.Failure]
        return rebind_var[Self](IO[_RootBlocking, Self.E]._lifted(_CurrentBlocking[Self.E]()).flat_map(_StartInterruptible[F, Self.E](function^)))

    @staticmethod
    def interruptible[R: Movable & Deinitable, //](function: def(Interruption) thin -> R) -> Self where R == Self.T:
        """Run a native interruptible function on the root's blocking pool."""
        return Self._interruptible(_NativeBorrow[Interruption, R, Never, def(Interruption) thin -> R, False](function))

    @staticmethod
    def interruptible[R: Movable & Deinitable, X: Movable & Deinitable, //](function: def(Interruption) raises X thin -> R) -> Self where R == Self.T and _ErrorCompatible[Self.E, X]:
        """Run a raising native interruptible function; its error becomes the failure."""
        return Self._interruptible(_NativeBorrow[Interruption, R, X, def(Interruption) raises X thin -> R, True](function))

    @staticmethod
    def eval_io[P: ReaderAction](var program: P) -> Self where IOContract[P].Compatible and P.Value == Self.T and IOContract[P].Error == Self.E:
        """Run a synchronous IO program inside this IO's context when reached.

        Parameters:
            P: A synchronous IO program producing T with error E.

        Args:
            program: The program, consumed; it runs once.

        Returns:
            An IO with the program's outcome.
        """
        return Self._lifted(_EvalIO(program^))

    @staticmethod
    def canceled() -> IO[NoneType, Self.E]:
        """Request cancellation of the running program.

        Returns:
            A unit IO; a mask defers observing the request.
        """
        return IO[NoneType, Self.E]._lifted(_EvalIO(_cancel_request[Self.E]()))

    @staticmethod
    def cede() -> IO[NoneType, Self.E]:
        """Yield to other work once, then continue.

        Returns:
            A unit IO that is runnable again after one yield.
        """
        return IO[NoneType, Self.E]._lifted(_Cede[Self.E]())

    def race_pair[U: Movable & Deinitable](deinit self, var other: IO[U, Self.E]) -> IO[RacePairResult[Self.T, U, Self.E], Self.E]:
        """Run both as fibers; produce the first one's outcome and the other's handle.

        The counterpart of Cats Effect's racePair. The left side wins a tie.
        The returned handle is a fiber of the running fiber, so it is joined,
        canceled, or drained by its owner like any child. If this program is
        canceled while waiting, both fibers are canceled and finish before it
        completes.

        Parameters:
            U: The right side's success type.

        Args:
            other: The right side, consumed.

        Returns:
            Left with the left outcome and the right fiber, or Right with the
            right outcome and the left fiber, each as a RaceWinner.
        """
        return self^.start()._bind(_StartRight[Self.T, U, Self.E](other^))

    def start(deinit self) -> IO[Fiber[Self.T, Self.E], Self.E]:
        """Start this IO as a fiber owned by the running fiber.

        The counterpart of Cats Effect's start. The child runs beside its owner
        and shares its error type; join or cancel it through the handle. When
        the owner's program finishes, it cancels its live children and waits
        for them, so a fiber never outlives its owner. Starting observes
        cancellation, like defer.

        Returns:
            An IO producing the started child's handle.
        """
        def invoke(var callable: _Erased, loop: MutOpaquePointer[_]):
            ref run = _loop_at[Self.E](loop)
            var record = run.record()
            _ = run.spawn(callable^.take[_Program[Self.E]](), record.copy())
            run.set_value(_Erased(Fiber[Self.T, Self.E](_record=record^)))

        return IO[Fiber[Self.T, Self.E], Self.E](_program=_Program[Self.E](_Head[Self.E](_DEFER, _Erased(self^._into_program()), invoke)))

    def eval_on(deinit self, target: ExecutionContext) -> Self:
        """Run this IO on `target`, then resume this fiber on its own root with the outcome.

        The counterpart of Cats Effect's `evalOn`. The IO runs as its own root
        on the target: on a work-stealing `Runtime`'s workers; on a
        current-thread `Runtime`, on one of its region threads (its configured
        blocking pool, or a private one); on a `BlockingPool`, on one of its
        threads for the whole region. Success, failure and cancellation pass
        through unchanged, and the caller always resumes on its own root, so
        nested regions return to each caller's context.

        Canceling the caller during the region cancels the IO and waits for it
        to finish; its finalizers run on the target, once. Children the IO
        starts belong to the region and are drained when it ends. The IO, its
        value and its error move to the target's threads and back, so they
        follow the thread-safety contract; a `Fiber`, `Supervisor` or `Poll`
        in T or E is rejected at compile time, since it is tied to its root.

        Args:
            target: The runtime or blocking pool to run on; the region keeps a
                copy, so the target cannot shut down while the IO runs.

        Returns:
            An IO with this IO's outcome.
        """
        comptime value_rejection = _root_bound_rejection[Self.T]("eval_on")
        comptime assert value_rejection.byte_length() == 0, value_rejection
        comptime error_rejection = _root_bound_rejection[Self.E]("eval_on")
        comptime assert error_rejection.byte_length() == 0, error_rejection
        return rebind_var[Self](IO[IORuntimeConfig, Self.E]._lifted(_CurrentSettings[Self.E]())._bind(_StartRegion[Self.T, Self.E](self^, target.copy())))

    def start_on(deinit self, target: ExecutionContext) -> IO[Fiber[Self.T, Self.E], Self.E]:
        """Start this IO as a fiber of the running fiber whose work runs on `target`.

        The counterpart of Cats Effect's `startOn`: `self.eval_on(target).start()`.
        The handle is an ordinary child of the caller; joining or canceling it
        reaches the region.

        Args:
            target: The runtime or blocking pool to run on.

        Returns:
            An IO producing the started child's handle.
        """
        return self^.eval_on(target).start()

    def background(deinit self) -> Resource[Background[Self.T, Self.E], Self.E]:
        """Start this IO as a fiber for the length of a resource's use, as Cats Effect's `background`.

        Acquiring the resource starts the fiber, owned by the fiber that uses
        the resource; releasing it cancels the fiber and waits for it. The
        value is a `Background` handle, whose `join` takes the fiber's
        outcome once. A failure no join took is reported, as for a dropped
        `Fiber`.

        Returns:
            A resource whose value is the fiber's handle.
        """
        return Resource[Background[Self.T, Self.E], Self.E](_BackgroundPlan[Self.T, Self.E](self^))

    def background_on(deinit self, target: ExecutionContext) -> Resource[Background[Self.T, Self.E], Self.E]:
        """Run this IO on `target` in the background, as Cats Effect's `backgroundOn`.

        `self.eval_on(target).background()`.

        Args:
            target: The runtime or blocking pool to run on.

        Returns:
            A resource whose value is the fiber's handle.
        """
        return self^.eval_on(target).background()

    @staticmethod
    def execution_context() -> IO[Optional[ExecutionContext], Self.E]:
        """The execution context running the current program.

        The counterpart of Cats Effect's `executionContext`. Inside
        `runtime.run(program)` it is that runtime, and inside an
        `eval_on(target)` region it is the target. Under the free `run`,
        `Driver` and `TestControl`, which have no `Runtime` value, it is None.

        Returns:
            An IO producing the context, or None.
        """
        return IO[Optional[ExecutionContext], Self.E]._lifted(_CurrentContext[Self.E]())

    @staticmethod
    def never() -> Self:
        """Wait until canceled.

        Returns:
            An IO that never produces a value.
        """
        return Self._lifted(_Never[Self.T, Self.E]())

    @staticmethod
    def sleep(duration: Duration) -> IO[NoneType, Self.E]:
        """Wait cooperatively for a duration measured from entry.

        Args:
            duration: The checked relative duration.

        Returns:
            A cancelable unit IO.
        """
        return IO[NoneType, Self.E]._lifted(_Sleep[Self.E](duration._nanoseconds))

    @staticmethod
    def monotonic() -> IO[Instant, Self.E]:
        """Read the inherited clock when the IO reaches it, as Cats Effect's IO.monotonic.

        Returns:
            An IO producing the current Instant: system monotonic time, or a
            manual clock's time, which moves only when its owner advances it.
        """
        return IO[Instant, Self.E]._lifted(_Monotonic[Self.E]())

    @staticmethod
    def real_time() -> IO[SystemTime, Self.E]:
        """Read the inherited wall clock when the IO reaches it, as Cats Effect's IO.realTime.

        Returns:
            An IO producing the current SystemTime: CLOCK_REALTIME, which can
            step backward when the system time is set, or, on a manual clock,
            the Unix epoch plus the manual clock's time. Measure elapsed time
            with monotonic.
        """
        return IO[SystemTime, Self.E]._lifted(_RealTime[Self.E]())

    def timed(deinit self) -> IO[Tuple[Duration, Self.T], Self.E]:
        """Run this IO and measure it on the inherited clock.

        Returns:
            An IO producing the elapsed Duration with the value; a failure or
            cancellation has no duration.
        """
        return _timed[_AsyncClock[Self.E], Self](self^)

    def timeout(deinit self, duration: Duration, var error: Self.E) -> Self:
        """Fail with an error after a duration, preferring this IO's drained result.

        Args:
            duration: The checked relative duration, anchored on entry.
            error: The domain error raised if the timer wins, consumed.

        Returns:
            An IO with this IO's outcome or the error; see timeout_to.
        """
        return self^.timeout_to(duration, Self.raise_error(error^))

    def delay_by(deinit self, duration: Duration) -> Self:
        """Sleep for a duration, then run this IO.

        Args:
            duration: The checked relative duration.

        Returns:
            An IO with this IO's outcome after the sleep.
        """
        return _delay_by[_AsyncClock[Self.E], Self](self^, duration)

    def and_wait(deinit self, duration: Duration) -> Self:
        """Run this IO, then sleep for a duration, keeping its value.

        Args:
            duration: The checked relative duration.

        Returns:
            An IO with this IO's value after the sleep; a failure does not sleep.
        """
        return _and_wait[_AsyncClock[Self.E], Self](self^, duration)

    def both[U: Movable & Deinitable](deinit self, var other: IO[U, Self.E]) -> IO[Tuple[Self.T, U], Self.E]:
        """Run this IO and another concurrently, draining both.

        Parameters:
            U: The other IO's value type.

        Args:
            other: The other IO, consumed.

        Returns:
            An IO of both values; failures keep left-before-right error order.
        """
        return self^.start()._bind(_StartPair[Self.T, U, Self.E, _BOTH](other^))

    def race[U: Movable & Deinitable](deinit self, var other: IO[U, Self.E]) -> IO[RaceResult[Self.T, U], Self.E]:
        """Race this IO against another; the loser is canceled and drained.

        Parameters:
            U: The other IO's value type.

        Args:
            other: The other IO, consumed.

        Returns:
            An IO of the first outcome that is not cancellation-only, tagged by side.
        """
        return self^.start()._bind(_StartPair[Self.T, U, Self.E, _RACE](other^))

    def race_first[U: Movable & Deinitable](deinit self, var other: IO[U, Self.E]) -> IO[RaceResult[Self.T, U], Self.E]:
        """Race by first terminal outcome; the loser is canceled and drained.

        Parameters:
            U: The other IO's value type.

        Args:
            other: The other IO, consumed.

        Returns:
            An IO of the first terminal outcome, tagged by side.
        """
        return self^.start()._bind(_StartPair[Self.T, U, Self.E, _RACE_FIRST](other^))

    def timeout_to(deinit self, duration: Duration, var fallback: Self) -> Self:
        """Fall back after a duration, preferring this IO's drained result.

        Args:
            duration: The checked relative duration, anchored on entry.
            fallback: Runs after the timer wins and this IO drains without a result.

        Returns:
            An IO retaining all errors from both and their cleanup.
        """
        return self^.start()._bind(_StartTimeout[Self.T, Self.E, True](duration._nanoseconds, fallback^))

    def timeout_after(deinit self, duration: Duration, var fallback: Self) -> Self:
        """Fall back by first terminal outcome after a duration.

        Args:
            duration: The checked relative duration, anchored on entry.
            fallback: Runs after the timer wins and this IO has drained.

        Returns:
            An IO retaining all errors from both and their cleanup.
        """
        return self^.start()._bind(_StartTimeout[Self.T, Self.E, False](duration._nanoseconds, fallback^))

    def poll(mut self, context: IOContext[Self.E]) -> Step[Self.T, Self.E]:
        """Advance the program; hosts and combinators call this, not applications.

        Args:
            context: The inherited cancellation and runtime context.

        Returns:
            A pending wait or the terminal outcome.
        """
        if not self._entered:
            var program = _Program[Self.E](_Head[Self.E]())
            swap(program, self._program)
            self._loop.unsafe_write(OwnedPointer(_RunLoop[Self.E](program^)))
            self._entered = True
        ref loop = self._loop.unsafe_assume_init()[]
        var step: Step[_Erased, Self.E]
        if loop.held:
            step = loop.drain(None)
        else:
            step = loop.run(context)
            if step._completed:
                # Fibers this IO started drain before it completes.
                step = loop.drain(Optional(step^))
        if not step._completed:
            return Step[Self.T, Self.E].pending(step^._waiting())
        var protected = step._protected_success
        var outcome = step^._outcome()
        if outcome and outcome.value().is_ok():
            # The run loop's final value was boxed by a head this IO's type fixed as T.
            var success: Outcome[Self.T, Self.E] = Optional(Result[Self.T, EffectFailure[Self.E]](Ok(outcome.take()._take_ok().take[Self.T]())))
            return Step[Self.T, Self.E]._make(Optional(success^), Wait(), protected)
        var failed = _failure_as[Self.T](outcome^)
        return Step[Self.T, Self.E]._make(Optional(failed^), Wait(), protected)


struct RaceWinner[T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable](Movable):
    """The side of a race_pair that finished first, and the other side's fiber.

    Take the outcome, then consume the value for the loser's handle, which is
    still a child of the running fiber.

    Parameters:
        T: The winner's success type.
        U: The loser's success type.
        E: The shared domain error.
    """
    var outcome: Outcome[Self.T, Self.E]
    """The winner's settled outcome."""
    var loser: Fiber[Self.U, Self.E]
    """The fiber that had not finished."""

    def __init__(out self, var outcome: Outcome[Self.T, Self.E], var loser: Fiber[Self.U, Self.E]):
        """Pair a winner's outcome with the loser's handle.

        Args:
            outcome: The winner's outcome, consumed.
            loser: The other fiber, consumed.
        """
        self.outcome = outcome^
        self.loser = loser^

    def take_outcome(mut self) -> Outcome[Self.T, Self.E]:
        """Move the winner's outcome out, leaving a cancellation-only outcome.

        Returns:
            The winner's outcome.
        """
        var outcome: Outcome[Self.T, Self.E] = None
        swap(outcome, self.outcome)
        return outcome^

    def into_loser(deinit self) -> Fiber[Self.U, Self.E]:
        """Consume this value for the loser's handle.

        Returns:
            The fiber that had not finished.
        """
        return self.loser^


comptime RacePairResult[T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable] = RaceResult[RaceWinner[T, U, E], RaceWinner[U, T, E]]
"""What race_pair produces: Left when the left side finished first, else Right.

Parameters:
    T: The left success type.
    U: The right success type.
    E: The shared domain error.
"""


@fieldwise_init
struct _StartRight[T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable](OnceUnary):
    var other: IO[Self.U, Self.E]
    comptime Arg = Fiber[Self.T, Self.E]
    comptime Out = IO[RacePairResult[Self.T, Self.U, Self.E], Self.E]

    def call_once(deinit self, var left: Fiber[Self.T, Self.E]) -> Self.Out:
        return self.other^.start()._bind(_AwaitFirst[Self.T, Self.U, Self.E](left^))


@fieldwise_init
struct _AwaitFirst[T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable](OnceUnary):
    var left: Fiber[Self.T, Self.E]
    comptime Arg = Fiber[Self.U, Self.E]
    comptime Out = IO[RacePairResult[Self.T, Self.U, Self.E], Self.E]

    def call_once(deinit self, var right: Fiber[Self.U, Self.E]) -> Self.Out:
        var first = _FirstDone[Self.E](self.left._claim.record.copy(), right._claim.record.copy(), False)
        return IO[Bool, Self.E]._lifted(first^)._bind(_JoinFirst[Self.T, Self.U, Self.E](self.left^, right^))


@fieldwise_init
struct _JoinFirst[T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable](OnceUnary):
    """Join the side that finished first; the other side's handle goes with it."""
    var left: Fiber[Self.T, Self.E]
    var right: Fiber[Self.U, Self.E]
    comptime Arg = Bool
    comptime Out = IO[RacePairResult[Self.T, Self.U, Self.E], Self.E]

    def call_once(deinit self, var left_first: Bool) -> Self.Out:
        if left_first:
            return self.left^.join()._mapped(_LeftFirst[Self.T, Self.U, Self.E](self.right^))
        return self.right^.join()._mapped(_RightFirst[Self.T, Self.U, Self.E](self.left^))


@fieldwise_init
struct _LeftFirst[T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable](OnceUnary):
    var right: Fiber[Self.U, Self.E]
    comptime Arg = Outcome[Self.T, Self.E]
    comptime Out = RacePairResult[Self.T, Self.U, Self.E]

    def call_once(deinit self, var outcome: Outcome[Self.T, Self.E]) -> Self.Out:
        return Self.Out(Left(RaceWinner[Self.T, Self.U, Self.E](outcome^, self.right^)))


@fieldwise_init
struct _RightFirst[T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable](OnceUnary):
    var left: Fiber[Self.T, Self.E]
    comptime Arg = Outcome[Self.U, Self.E]
    comptime Out = RacePairResult[Self.T, Self.U, Self.E]

    def call_once(deinit self, var outcome: Outcome[Self.U, Self.E]) -> Self.Out:
        return Self.Out(Right(RaceWinner[Self.U, Self.T, Self.E](outcome^, self.left^)))


# Pair policies over two fibers: first terminal, first non-canceled, or both.
comptime _RACE_FIRST = 0
comptime _RACE = 1
comptime _BOTH = 3
comptime _PairValue[T: Movable & Deinitable, U: Movable & Deinitable, policy: Int] = Tuple[T, U] if policy == _BOTH else RaceResult[T, U]


@fieldwise_init
struct _StartPair[T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable, policy: Int](OnceUnary):
    var other: IO[Self.U, Self.E]
    comptime Arg = Fiber[Self.T, Self.E]
    comptime Out = IO[_PairValue[Self.T, Self.U, Self.policy], Self.E]

    def call_once(deinit self, var left: Fiber[Self.T, Self.E]) -> Self.Out:
        return self.other^.start()._bind(_AwaitPair[Self.T, Self.U, Self.E, Self.policy](left^))


@fieldwise_init
struct _AwaitPair[T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable, policy: Int](OnceUnary):
    var left: Fiber[Self.T, Self.E]
    comptime Arg = Fiber[Self.U, Self.E]
    comptime Out = IO[_PairValue[Self.T, Self.U, Self.policy], Self.E]

    def call_once(deinit self, var right: Fiber[Self.U, Self.E]) -> Self.Out:
        return Self.Out._lifted(_PairJoin[Self.T, Self.U, Self.E, Self.policy](Optional(self.left^), Optional(right^), -1, False, -1))


@fieldwise_init
struct _PairJoin[T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable, policy: Int](Machine):
    """Wait for two fibers, stopping them by policy, then combine their outcomes.

    Fibers own and drain the children; this leaf only forwards cancellation and
    combines. A race stops the other side once one finishes; both stops the
    other side when one ends unsuccessfully. The parent's request is forwarded
    when observed, and every entered child finishes before the leaf completes.

    As in Cats Effect, a side that both stops because the other failed ends
    canceled as expected, like a race's loser: `_loser` keeps its errors and
    drops that cancellation, so the result is the failure, which
    `handle_error_with` can recover. A side that canceled itself first, or a
    forwarded parent request, still yields cancellation.
    Stopping and draining waits are the child-group helpers `_stop_child` and
    `_child_wait`, and `_zip_outcomes` combines through `_finish`, which
    AsyncPar's loop shares for any number of children.
    """
    comptime Value = _PairValue[Self.T, Self.U, Self.policy]
    comptime Error = Self.E
    var left: Optional[Fiber[Self.T, Self.E]]
    var right: Optional[Fiber[Self.U, Self.E]]
    var winner: Int
    var stopping: Bool
    # Both only: the side that ended unsuccessfully before anything stopped
    # the pair, or -1. Observed together, the left side is first.
    var failed: Int

    def stop(mut self):
        if not self.stopping:
            self.stopping = True
            _stop_child(self.left.value()._claim.record[])
            _stop_child(self.right.value()._claim.record[])

    def poll(mut self, context: IOContext[Self.E]) -> Step[Self.Value, Self.E]:
        ref left = self.left.value()._claim.record[]
        ref right = self.right.value()._claim.record[]
        var left_revision = left.signal.revision()
        var right_revision = right.signal.revision()
        if context.canceled():
            self.stop()
        if self.winner < 0:
            if left.done():
                self.winner = 0
            elif right.done():
                self.winner = 1
            comptime if Self.policy != _BOTH:
                if self.winner >= 0:
                    self.stop()
        comptime if Self.policy == _BOTH:
            if self.failed < 0 and not self.stopping:
                if _unsuccessful(left):
                    self.failed = 0
                elif _unsuccessful(right):
                    self.failed = 1
            if _unsuccessful(left) or _unsuccessful(right):
                self.stop()
        if left.done() and right.done():
            var left_outcome = _typed[Self.T](self.left.take()._take_outcome())
            var right_outcome = _typed[Self.U](self.right.take()._take_outcome())
            comptime if Self.policy == _BOTH:
                # The side stopped because the other failed folds as a race's
                # loser; errors stay in left-to-right order.
                if self.failed == 0:
                    return Step[Self.Value, Self.E].ready(rebind_var[Outcome[Self.Value, Self.E]](_failure_as[Tuple[Self.T, Self.U]](_finish(left_outcome^, _loser(right_outcome^)))))
                if self.failed == 1:
                    return Step[Self.Value, Self.E].ready(rebind_var[Outcome[Self.Value, Self.E]](_failure_as[Tuple[Self.T, Self.U]](_finish(_loser(left_outcome^), right_outcome^))))
                return Step[Self.Value, Self.E].ready(rebind_var[Outcome[Self.Value, Self.E]](_zip_outcomes(left_outcome^, right_outcome^)))
            else:
                var selected = self.winner
                comptime if Self.policy == _RACE:
                    # A cancellation-only winner yields to the other side's drained result.
                    if selected == 0 and not left_outcome:
                        selected = 1
                    elif selected == 1 and not right_outcome:
                        selected = 0
                if selected == 0:
                    return Step[Self.Value, Self.E].ready(rebind_var[Outcome[Self.Value, Self.E]](_finish(_winner[Self.T, Self.U, Self.E, True](left_outcome^), _loser(right_outcome^))))
                return Step[Self.Value, Self.E].ready(rebind_var[Outcome[Self.Value, Self.E]](_finish(_winner[Self.T, Self.U, Self.E, False](right_outcome^), _loser(left_outcome^))))
        # A forwarded request must not wake cleanup that is still draining.
        var either = _child_wait(left.signal, left_revision, self.stopping)
        either._include(_child_wait(right.signal, right_revision, self.stopping), context)
        return Step[Self.Value, Self.E].pending(either^)


@fieldwise_init
struct _StartTimeout[T: Movable & Deinitable, E: Movable & Deinitable, prefer_source: Bool](OnceUnary):
    var nanoseconds: Int
    var fallback: IO[Self.T, Self.E]
    comptime Arg = Fiber[Self.T, Self.E]
    comptime Out = IO[Self.T, Self.E]

    def call_once(deinit self, var source: Fiber[Self.T, Self.E]) -> IO[Self.T, Self.E]:
        var waiting = IO[RaceResult[Self.T, NoneType], Self.E]._lifted(_TimeoutJoin[Self.T, Self.E, Self.prefer_source](Optional(source^), self.nanoseconds, None, -1, False))
        return waiting^._bind(_TimeoutBranch[Self.T, Self.E](self.fallback^))


@fieldwise_init
struct _TimeoutJoin[T: Movable & Deinitable, E: Movable & Deinitable, prefer_source: Bool](Machine):
    """Race a source fiber against a deadline anchored on this leaf's first poll.

    The timer wins only if the deadline passes before the source finishes; the
    source is then canceled and drained. timeout_to keeps a source outcome that
    is not cancellation-only even after the timer wins.
    """
    comptime Value = RaceResult[Self.T, NoneType]
    comptime Error = Self.E
    var source: Optional[Fiber[Self.T, Self.E]]
    var nanoseconds: Int
    var deadline: Optional[Instant]
    var winner: Int
    var stopping: Bool

    def poll(mut self, context: IOContext[Self.E]) -> Step[Self.Value, Self.E]:
        ref source = self.source.value()._claim.record[]
        var revision = source.signal.revision()
        var now = context._clock.now()
        if not self.deadline:
            self.deadline = Optional(now._after_nanoseconds(self.nanoseconds))
        if context.canceled() and not self.stopping:
            self.stopping = True
            source.token.cancel()
        if self.winner < 0:
            if source.done():
                self.winner = 0
            elif now >= self.deadline.value():
                self.winner = 1
                if not self.stopping:
                    self.stopping = True
                    source.token.cancel()
        if source.done():
            var outcome = _typed[Self.T](self.source.take()._take_outcome())
            var selected = self.winner
            comptime if Self.prefer_source:
                if selected == 1 and outcome:
                    selected = 0
            var unit: NoneType = None
            var elapsed: Outcome[NoneType, Self.E] = Optional(Result[NoneType, EffectFailure[Self.E]](Ok(unit)))
            if selected == 0:
                return Step[Self.Value, Self.E].ready(_finish(_winner[Self.T, NoneType, Self.E, True](outcome^), _loser(elapsed^)))
            return Step[Self.Value, Self.E].ready(_finish(_winner[Self.T, NoneType, Self.E, False](elapsed^), _loser(outcome^)))
        var wait = Wait.changed(source.signal, revision)
        wait._interruptible = not self.stopping
        if self.winner < 0:
            var timer = Wait.until(self.deadline.value())
            timer._interruptible = False
            wait._include(timer, context)
        return Step[Self.Value, Self.E].pending(wait^)


@fieldwise_init
struct _TimeoutBranch[T: Movable & Deinitable, E: Movable & Deinitable](OnceUnary):
    """Keep the source's value, or run the fallback once the timer won."""
    var fallback: IO[Self.T, Self.E]
    comptime Arg = RaceResult[Self.T, NoneType]
    comptime Out = IO[Self.T, Self.E]

    def call_once(deinit self, var selected: RaceResult[Self.T, NoneType]) -> IO[Self.T, Self.E]:
        if selected.isa[Left[Self.T]]():
            return IO[Self.T, Self.E].pure(selected^.unwrap[Left[Self.T]]().into_payload())
        return self.fallback^


comptime _PollOf[E: Movable & Deinitable] = Poll[E]
"""The async Poll type, named outside Async where its member would shadow it."""

comptime _CaseFinalizer[F: Movable & Deinitable, E: Movable & Deinitable] = (
    downcast[F, BorrowCallContract].Payload == ExitCase[E] and downcast[F, BorrowCallContract].Result == IO[NoneType, E]
    and _OnceBorrowAvailable[downcast[F, BorrowCallContract & Movable & Deinitable]]
    and _ErrorCompatible[E, downcast[F, BorrowCallContract].Failure]
    and _Admitted[F]) if conforms_to(F, BorrowCallContract) else False


# A function with no return value produces the unit value (shared with blocking).
comptime _DelayValue[R: Movable & Deinitable] = _CallValue[R]


@fieldwise_init
struct _Delay[F: ThunkContract & Movable & Deinitable, E: Movable & Deinitable](OnceThunk):
    """Evaluate a synchronous function into a pure IO."""
    var function: Self.F
    comptime Out = IO[_DelayValue[Self.F.Out], Self.E]
    comptime Error = Self.F.Error

    def call_once(deinit self) raises Self.Error -> Self.Out:
        comptime if Self.F.Out == type_of(None):
            _ = _thunk_once_as[Self.Error](self.function^)
            var unit: NoneType = None
            return rebind_var[Self.Out](IO[NoneType, Self.E].pure(unit))
        else:
            return rebind_var[Self.Out](IO[Self.F.Out, Self.E].pure(_thunk_once_as[Self.Error](self.function^)))


@fieldwise_init
struct _StartBlocking[F: ThunkContract & Movable & Deinitable, E: Movable & Deinitable](OnceUnary):
    """Register a blocking call on the root's pool inside a masked region."""
    var function: Self.F
    comptime Arg = _RootBlocking
    comptime Out = IO[_DelayValue[Self.F.Out], Self.E]

    def call_once(deinit self, var root: _RootBlocking) -> Self.Out:
        return Self.Out.uncancelable(_MaskedBlocking[Self.F, Self.E](self.function^, root^))


@fieldwise_init
struct _MaskedBlocking[F: ThunkContract & Movable & Deinitable, E: Movable & Deinitable](OnceUnary):
    """The masked registration: its wait ignores cancellation, as Cats Effect's blocking."""
    var function: Self.F
    var root: _RootBlocking
    comptime Arg = Poll[Self.E]
    comptime Out = IO[_DelayValue[Self.F.Out], Self.E]

    def call_once(deinit self, var poll: Poll[Self.E]) -> Self.Out:
        return Self.Out.async_(_SubmitBlocking[Self.F, Self.E](self.function^, self.root^))


struct _StartRegion[T: Movable & Deinitable, E: Movable & Deinitable](OnceUnary):
    """Register an `eval_on` region; its withdrawal cancels the region and waits for its end (`contexts.mojo`)."""
    var program: IO[Self.T, Self.E]
    var target: ExecutionContext
    comptime Arg = IORuntimeConfig
    comptime Out = IO[Self.T, Self.E]

    def __init__(out self, var program: IO[Self.T, Self.E], var target: ExecutionContext):
        self.program = program^
        self.target = target^

    def call_once(deinit self, var settings: IORuntimeConfig) -> Self.Out:
        var interrupt = _Interrupt[Self.E]()
        var withdrawal = IO[NoneType, Self.E].async_(_AwaitReturn[Self.E](interrupt.copy()))
        return Self.Out.`async`(_SubmitRegion[IO[Self.T, Self.E]](self.program^, self.target^, settings^, interrupt^), withdrawal^)


@fieldwise_init
struct _StartInterruptible[F: BorrowCallContract & Movable & Deinitable, E: Movable & Deinitable](OnceUnary):
    """Register an interruptible call; its withdrawal interrupts and waits for the return."""
    var function: Self.F
    comptime Arg = _RootBlocking
    comptime Out = IO[Self.F.Result, Self.E]

    def call_once(deinit self, var root: _RootBlocking) -> Self.Out:
        var interrupt = _Interrupt[Self.E]()
        var withdrawal = IO[NoneType, Self.E].async_(_AwaitReturn[Self.E](interrupt.copy()))
        return Self.Out.`async`(_SubmitInterruptible[Self.F, Self.E](self.function^, root^, interrupt^), withdrawal^)


struct _Cede[E: Movable & Deinitable](Machine, Defaultable):
    """Yield once as runnable, then succeed."""
    comptime Value = NoneType
    comptime Error = Self.E
    var _yielded: Bool

    def __init__(out self):
        self._yielded = False

    def poll(mut self, context: IOContext[Self.E]) -> Step[NoneType, Self.E]:
        if not self._yielded:
            self._yielded = True
            return Step[NoneType, Self.E].pending(Wait())
        var unit: NoneType = None
        return Step[NoneType, Self.E].ready(Optional(Result[NoneType, EffectFailure[Self.E]](Ok(unit))))


struct _AsyncClock[E: Movable & Deinitable](_SleepSource, not Deinitable):
    """IO's clock reading and sleep, for the shared derived time operations."""
    comptime Family = Async[Self.E]
    comptime Reading = IO[Instant, Self.E]
    comptime RealReading = IO[SystemTime, Self.E]
    comptime Slept = IO[NoneType, Self.E]

    @staticmethod
    def read() -> IO[Instant, Self.E]:
        return IO[Instant, Self.E].monotonic()

    @staticmethod
    def read_real() -> IO[SystemTime, Self.E]:
        return IO[SystemTime, Self.E].real_time()

    @staticmethod
    def sleep(duration: Duration) -> IO[NoneType, Self.E]:
        return IO[NoneType, Self.E].sleep(duration)


struct _Monotonic[E: Movable & Deinitable](Machine, Defaultable):
    """Read the inherited clock once."""
    comptime Value = Instant
    comptime Error = Self.E

    def __init__(out self):
        pass

    def poll(mut self, context: IOContext[Self.E]) -> Step[Instant, Self.E]:
        return Step[Instant, Self.E].ready(Optional(Result[Instant, EffectFailure[Self.E]](Ok(context.now()))))


struct _RealTime[E: Movable & Deinitable](Machine, Defaultable):
    """Read the inherited wall clock once."""
    comptime Value = SystemTime
    comptime Error = Self.E

    def __init__(out self):
        pass

    def poll(mut self, context: IOContext[Self.E]) -> Step[SystemTime, Self.E]:
        return Step[SystemTime, Self.E].ready(Optional(Result[SystemTime, EffectFailure[Self.E]](Ok(context._clock.real_now()))))


struct _Never[T: Movable & Deinitable, E: Movable & Deinitable](Machine, Defaultable):
    """Wait without a wake source; only cancellation completes it."""
    comptime Value = Self.T
    comptime Error = Self.E

    def __init__(out self):
        pass

    def poll(mut self, context: IOContext[Self.E]) -> Step[Self.T, Self.E]:
        if context.canceled():
            return Step[Self.T, Self.E].ready(None)
        var wait = Wait.never()
        wait._interruptible = not context._masked
        return Step[Self.T, Self.E].pending(wait^)


@fieldwise_init
struct _Combine[F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable, E: Movable & Deinitable](OnceUnary):
    """After the left value: build the right IO, then combine the two values."""
    var function: Self.F
    var right: Self.R
    comptime Arg = Self.F.First
    comptime Out = IO[Self.F.Out, Self.E]
    comptime Error = Self.R.Error

    def call_once(deinit self, var value: Self.Arg) raises Self.Error -> Self.Out:
        var right = _thunk_once_as[Self.Error](self.right^)
        return rebind_var[IO[Self.F.Second, Self.E]](right^)._mapped(_BindFirst(self.function^, value^))


@fieldwise_init
struct _FoldState[V: Movable & Deinitable, P: Movable & Deinitable, F: Movable & Deinitable](Movable):
    var source: _Source[Self.V]
    var prepare: Self.P
    var function: Self.F


@fieldwise_init
struct _Fold[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator, E: Movable & Deinitable](OnceUnary):
    """One dependent fold step; the next step binds after the step's IO.

    The run loop applies each bind from its frame stack, so a fold of any
    length uses constant native stack. One allocation holds the fold state.
    """
    var state: OwnedPointer[_FoldState[Self.V, Self.P, Self.F]]
    comptime Arg = Self.K.Acc
    comptime Out = IO[Self.K.Acc, Self.E]
    comptime Error = Self.E

    def call_once(deinit self, var acc: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.P] and RepeatableBinary[Self.F]
        comptime assert Self.P.Arg == _Source[Self.V].Element and Self.P.Out == Self.F.Second and Self.F.First == Self.Arg and Self.F.Out == Self.Out
        comptime assert _ErrorCompatible[Self.E, Self.P.Error] and _ErrorCompatible[Self.E, Self.F.Error]
        if not Self.K.live(acc):
            return Self.Out.pure(acc^)
        var item = _next_optional[Self.P.Arg](self.state[].source)
        if not item:
            return Self.Out.pure(acc^)
        var prepared = _unary_repeated_as[Self.E](self.state[].prepare, item.take())
        var next = _binary_repeated_as[Self.E](self.state[].function, rebind_var[Self.F.First](acc^), rebind_var[Self.F.Second](prepared^))
        return rebind_var[Self.Out](next^)._bind(Self(self.state^))


def _start_fold[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator, E: Movable & Deinitable](var source: V, var prepare: P, var function: F, var initial: K.Acc) raises E -> IO[K.Acc, E]:
    return _Fold[V, P, F, K, E](OwnedPointer(_FoldState[V, P, F](_source(source^), prepare^, function^))).call_once(initial^)


@fieldwise_init
struct _StartFold[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator, E: Movable & Deinitable](OnceThunk):
    """Open the source and take the first step when the fold runs."""
    var source: Self.V
    var prepare: Self.P
    var function: Self.F
    var initial: Self.K.Acc
    comptime Out = IO[Self.K.Acc, Self.E]
    comptime Error = Self.E

    def call_once(deinit self) raises Self.Error -> Self.Out:
        return _start_fold[Self.V, Self.P, Self.F, Self.K, Self.E](self.source^, self.prepare^, self.function^, self.initial^)


@fieldwise_init
struct _CollectStep[F: UnaryContract & Movable & Deinitable, K: _Accumulate, E: Movable & Deinitable](MutableBinary):
    """Run the callback's IO, then accumulate its value."""
    var function: Self.F
    comptime First = Self.K.Acc
    comptime Second = Self.F.Arg
    comptime Out = IO[Self.K.Acc, Self.E]
    comptime Error = Self.F.Error

    def call_mut(mut self, var acc: Self.First, var item: Self.Second) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F]
        var next = _unary_repeated_as[Self.Error](self.function, item^)
        return rebind_var[IO[Self.K.Item, Self.E]](next^)._mapped(_BindFirst(_AccumulatePair[Self.K](), acc^))


@fieldwise_init
struct _StartCollect[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate, E: Movable & Deinitable](OnceThunk):
    """Start the accumulator and fold when the collection runs."""
    var source: Self.V
    var function: Self.F
    comptime Out = IO[Self.K.Acc, Self.E]
    comptime Error = Self.E

    def call_once(deinit self) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.E, Self.K.Error]
        var start = _start_as[Self.E, Self.K]()
        return _start_fold[Self.V, Identity[Self.F.Arg], _CollectStep[Self.F, Self.K, Self.E], Self.K, Self.E](self.source^, Identity[Self.F.Arg](), _CollectStep[Self.F, Self.K, Self.E](self.function^), start^)


# --- Concurrent collection -------------------------------------------------
#
# AsyncPar's loop. When the IO runs it enters one masked region, pulls the
# source in order, calls the callback on the parent fiber in source order and
# starts each element's IO as a child fiber, with at most `limit` children
# live. A finished child announces itself on the group's completion stack; the
# waiting leaf takes every announcement in one step, so a completion costs O(1)
# and the waiter registers on one group signal instead of every child's.
# Results enter the accumulation rule in source order. The child policy is
# `both`'s, through the helpers `_PairJoin` shares: the first child that ends
# unsuccessfully stops the rest, the parent's cancellation is forwarded (seen
# through the region's Poll, so an outer mask still holds), every started
# child is drained, and the failure folds every observed outcome in element
# order with `_finish`. The region is masked so that no bind checkpoint can
# drop the loop's state, and with it the children's claims, between steps.


@always_inline
def _stop_child[E: Movable & Deinitable](record: _FiberRecord[E]):
    """Stop one child of a group: request its cancellation."""
    record.token.cancel()


@always_inline
def _child_wait(signal: _Signal, revision: UInt64, stopping: Bool) -> Wait:
    """Wait for a child's or a group's signal; once stopping, a forwarded request must not wake cleanup that is still draining."""
    var wait = Wait.changed(signal, revision)
    wait._interruptible = not stopping
    return wait^


struct _ParNode(Movable):
    """One child's announcement: its element index, with the stack link embedded once.

    `announced` makes announcing idempotent: the child's finalizer and the
    parent's check of a refused child may both try, and exactly one pushes.
    It orders nothing (the push publishes the node), so it is RELAXED, and a
    party that reads it set leaves without a read-modify-write.
    """
    var link: _StackLink[_ParDone]
    var index: Int
    var announced: Atomic[UInt8]

    def __init__(out self, index: Int):
        self.link = _StackLink[_ParDone]()
        self.index = index
        self.announced = Atomic(UInt8(0))


struct _ParDone(_Linked):
    """A completion stack element: the handle to a child's node."""
    var node: ArcPointer[_ParNode]

    def __init__(out self, var node: ArcPointer[_ParNode]):
        self.node = node^

    def _link_address(self) -> Int:
        return Int(Pointer(to=self.node[].link))


struct _ParGroup(Movable):
    """The completion structure one concurrent loop shares with its children.

    Children announce from their own tasks, possibly on other workers, while
    the parent takes announcements, so every method takes immutable `self`;
    the stack's head lives in its own cache-line allocation and the signal in
    its own cell. Memory ordering:

    - `finished` pushes with the stack's RELEASE install and, when that push
      made the stack non-empty, notifies the signal, whose lock orders the push
      before a waiter's later revision read. Every node on the stack sits above
      the first one since the last take, whose pusher notifies after pushing,
      so a waiter that took before that push sees the revision change.
    - `take` detaches with the stack's ACQUIRE compare-exchange, so a taken
      node's index is visible. A waiter reads the revision first, then takes:
      a push after the take bumps the revision, and `Wait.changed` rechecks it
      when registering, so no announcement is lost.
    - `arrived` is a RELAXED hint read: a stale answer only delays a take to
      the next step, which the signal then guarantees.

    An announcement precedes the child's published outcome (it runs from the
    child's finalizer), so the parent checks the record and waits on its
    signal in the rare case it has not yet completed.
    """
    var signal: _Signal
    var done: _ClosableStack[_ParDone]

    def __init__(out self):
        self.signal = _Signal()
        self.done = _ClosableStack[_ParDone]()

    def finished(self, var node: ArcPointer[_ParNode]):
        """Announce a child's completion once: push its node, then wake the waiter."""
        if node[].announced.load[ordering=Ordering.RELAXED]() != 0:
            return
        var idle = UInt8(0)
        if not node[].announced.compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.RELAXED](idle, UInt8(1)):
            return
        var first = False
        if self.done.push_first(_ParDone(node^), first):
            abort("a concurrent loop's completion stack closed while children ran")
        # Only the push that makes the stack non-empty wakes the waiter, which
        # takes everything at once; later pushes find a wake already sent.
        if first:
            self.signal.notify()

    def take(self) -> List[_ParDone]:
        """Every announcement since the last take, oldest first."""
        return self.done.take_all()

    def arrived(self) -> Bool:
        return not self.done.is_empty()


@fieldwise_init
struct _ParNotice(Movable):
    """What a child's finalizer needs to announce it."""
    var group: ArcPointer[_ParGroup]
    var node: ArcPointer[_ParNode]

    def announce(deinit self):
        self.group[].finished(self.node^)


def _par_notice[E: Movable & Deinitable](var factory: _Erased, exit: ExitCase[E]) -> _Program[E]:
    """The child's last finalizer: announce, then finish with nothing to run."""
    factory^.take[_ParNotice]().announce()
    return IO[NoneType, E].pure(None)._into_program()


struct _ParSlot[T: Movable & Deinitable, E: Movable & Deinitable](Movable):
    """One started element: its fiber until it finishes, then its outcome."""
    var fiber: Optional[Fiber[Self.T, Self.E]]
    var outcome: Optional[Outcome[Self.T, Self.E]]
    # Whether the outcome was taken after the loop stopped its children.
    var stopped: Bool

    def __init__(out self):
        self.fiber = None
        self.outcome = None
        self.stopped = False


comptime _PAR_UNBOUNDED = Int.MAX
comptime _PAR_BATCH = 32
"""Launches between visits to the waiting leaf.

Launching runs in the masked region, where nothing observes the parent's
cancellation, and an unbounded loop could otherwise start every element of a
long source before it next takes announcements. The leaf observes both, so a
failure or a cancellation stops the source within 32 elements. A visit costs
one leaf allocation and one revision read, under 1% of 32 fiber starts; a
pending announcement also sends the loop to the leaf early.
"""


struct _ParState[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate, E: Movable & Deinitable](Movable):
    """The loop's state, owned by whichever step runs: a launch or the waiting leaf.

    `slots` holds the elements from `base`, the first not yet accumulated, to
    `next`; finished ones keep their outcome until every earlier one has
    finished. `live` counts started children whose outcome is not yet taken.
    """
    comptime T = Self.K.Item
    var source: _Source[Self.V]
    var function: Self.F
    var limit: Int
    var poll: Poll[Self.E]
    var group: ArcPointer[_ParGroup]
    var slots: List[_ParSlot[Self.T, Self.E]]
    var head: Int
    var base: Int
    var next: Int
    var live: Int
    var late: List[Int]
    var acc: Optional[Self.K.Acc]
    var exhausted: Bool
    var stopping: Bool
    var forwarded: Bool
    var abandoned: Bool
    var batch: Int
    # Once stopping: the first element whose child may still be running.
    var cursor: Int

    def __init__(out self, var source: Self.V, var function: Self.F, limit: Int, var poll: Poll[Self.E], var acc: Self.K.Acc):
        self.source = _source(source^)
        self.function = function^
        self.limit = limit
        self.poll = poll^
        self.group = ArcPointer(_ParGroup())
        self.slots = List[_ParSlot[Self.T, Self.E]]()
        self.head = 0
        self.base = 0
        self.next = 0
        self.live = 0
        self.late = List[Int]()
        self.acc = Optional(acc^)
        self.exhausted = False
        self.stopping = False
        self.forwarded = False
        self.abandoned = False
        self.batch = 0
        self.cursor = 0

    def position(self, index: Int) -> Int:
        """Where element `index` sits in `slots`."""
        return self.head + index - self.base

    def stop(mut self):
        """Stop every live child once."""
        if self.stopping:
            return
        self.stopping = True
        self.cursor = self.base
        for position in range(self.head, len(self.slots)):
            if self.slots[position].fiber:
                _stop_child(self.slots[position].fiber.value()._claim.record[])

    def fail_at(mut self, index: Int, var error: Self.E):
        """An error that belongs to element `index`: its callback's or its accumulation's."""
        self.slots[self.position(index)].outcome = Optional(Outcome[Self.T, Self.E](Result[Self.T, EffectFailure[Self.E]](Err(EffectFailure[Self.E](NonEmptyList(error^), False)))))
        self.stop()

    def settle(mut self, index: Int) -> Bool:
        """Take a finished child's outcome; false if its record has not completed yet."""
        var position = self.position(index)
        if not self.slots[position].fiber:
            return True
        if not self.slots[position].fiber.value()._claim.record[].done():
            return False
        var after_stop = self.stopping
        var outcome = _typed[Self.T](self.slots[position].fiber.take()._take_outcome())
        if not outcome or outcome.value().is_err():
            self.stop()
        self.slots[position].outcome = Optional(outcome^)
        self.slots[position].stopped = after_stop
        self.live -= 1
        return True

    def gather(mut self):
        """Take every announcement and every late record that has completed since."""
        var late = List[Int]()
        swap(late, self.late)
        for index in late:
            if not self.settle(index):
                self.late.append(index)
        var arrived = self.group[].take()
        for index in range(len(arrived)):
            var position = arrived[index].node[].index
            if not self.settle(position):
                self.late.append(position)

    def accumulate(mut self):
        """Fold the finished successful prefix into the accumulator, in source order."""
        while not self.stopping and self.base < self.next:
            if not self.slots[self.head].outcome or not self.slots[self.head].outcome.value() or self.slots[self.head].outcome.value().value().is_err():
                return
            var outcome = self.slots[self.head].outcome.take()
            var item = outcome.take()._take_ok()
            var index = self.base
            self.head += 1
            self.base += 1
            comptime assert _ErrorCompatible[Self.E, Self.K.Error]
            try:
                var next = _combine_as[Self.E, Self.K](self.acc.take(), item^)
                self.acc = Optional(next^)
            except error:
                # The accumulator is gone with the failed step, as in sequence.
                self.base -= 1
                self.head -= 1
                self.fail_at(index, error^)
                return
            if not Self.K.live(self.acc.value()):
                self.abandoned = True
                self.stop()
        if self.head > 64 and 2 * self.head > len(self.slots):
            var kept = List[_ParSlot[Self.T, Self.E]](capacity=len(self.slots) - self.head)
            for position in range(self.head, len(self.slots)):
                kept.append(_ParSlot[Self.T, Self.E]())
                swap(kept[len(kept) - 1], self.slots[position])
            self.slots = kept^
            self.head = 0

    def outcome(mut self) -> Outcome[NoneType, Self.E]:
        """After draining: every unaccumulated element's outcome folded in element order.

        An element taken after the loop stopped its children folds as a race's
        loser, as in Cats Effect: its errors remain, but the cancellation the
        loop caused does not mark the failure canceled, so `handle_error_with`
        recovers it. An element that canceled itself, or a forwarded parent
        request, still yields cancellation.
        """
        var unit: NoneType = None
        var folded: Outcome[NoneType, Self.E] = Optional(Result[NoneType, EffectFailure[Self.E]](Ok(unit)))
        for position in range(self.head, len(self.slots)):
            if self.slots[position].outcome:
                if self.slots[position].stopped:
                    folded = _finish(folded^, _loser(self.slots[position].outcome.take()))
                else:
                    folded = _finish(folded^, self.slots[position].outcome.take())
        if self.forwarded:
            if not folded:
                return None
            if folded.value().is_ok():
                # Cancellation stopped the loop before its source was done.
                return None
            var failure = folded.take()._take_err()
            failure.canceled = True
            return Optional(Result[NoneType, EffectFailure[Self.E]](Err(failure^)))
        return folded^


comptime _ParBox[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate, E: Movable & Deinitable] = OwnedPointer[_ParState[V, F, K, E]]


struct _ParWait[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate, E: Movable & Deinitable](Machine):
    """The loop's waiting leaf: take announcements, accumulate, stop, drain.

    Completes with the state when the loop can launch again or has finished
    successfully, and with the loop's final failure or cancellation once a
    stopped loop has drained.
    """
    comptime Value = _ParBox[Self.V, Self.F, Self.K, Self.E]
    comptime Error = Self.E
    var state: Optional[_ParBox[Self.V, Self.F, Self.K, Self.E]]

    def __init__(out self, var state: _ParBox[Self.V, Self.F, Self.K, Self.E]):
        self.state = Optional(state^)

    def poll(mut self, context: IOContext[Self.E]) -> Step[Self.Value, Self.E]:
        ref state = self.state.value()[]
        # The region's Poll shows the cancellation state outside this mask.
        var outer = state.poll._source._restore(context)
        # Read the revision before taking announcements (see _ParGroup).
        var revision = state.group[].signal.revision()
        if outer.canceled() and not state.stopping:
            state.forwarded = True
            state.stop()
        state.gather()
        state.accumulate()
        # A child stopped before its first poll never enters its program, so
        # it never announces: drain stopped children by their records, in
        # element order, waiting on one record at a time.
        var draining: Optional[_Signal] = None
        var drain_revision = UInt64(0)
        if state.stopping:
            while state.cursor < state.next:
                var position = state.position(state.cursor)
                if state.slots[position].fiber:
                    var signal = state.slots[position].fiber.value()._claim.record[].signal.copy()
                    var record_revision = signal.revision()
                    if not state.settle(state.cursor):
                        draining = Optional(signal^)
                        drain_revision = record_revision
                        break
                state.cursor += 1
            if state.live == 0:
                if state.abandoned:
                    return Step[Self.Value, Self.E].ready(Optional(Result[Self.Value, EffectFailure[Self.E]](Ok(self.state.take()))))
                var outcome = _failure_as[Self.Value](state.outcome())
                _ = self.state.take()
                return Step[Self.Value, Self.E].ready(outcome^)
        elif (state.live < state.limit and not state.exhausted) or state.live == 0:
            return Step[Self.Value, Self.E].ready(Optional(Result[Self.Value, EffectFailure[Self.E]](Ok(self.state.take()))))
        var wait = Wait.never()
        wait._interruptible = False
        wait._include(_child_wait(state.group[].signal, revision, state.stopping), outer)
        if draining:
            wait._include(_child_wait(draining.value(), drain_revision, True), outer)
            return Step[Self.Value, Self.E].pending(wait^)
        for index in state.late:
            # Announced before its record published: wait on the record itself.
            ref record = state.slots[state.position(index)].fiber.value()._claim.record[]
            var late_revision = record.signal.revision()
            if record.done():
                return Step[Self.Value, Self.E].pending(Wait())
            wait._include(_child_wait(record.signal, late_revision, state.stopping), outer)
        return Step[Self.Value, Self.E].pending(wait^)


struct _ParResume[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate, E: Movable & Deinitable](OnceUnary, Defaultable):
    """After the waiting leaf: launch again, or finish."""
    comptime Arg = _ParBox[Self.V, Self.F, Self.K, Self.E]
    comptime Out = IO[Self.K.Acc, Self.E]

    def __init__(out self):
        pass

    def call_once(deinit self, var state: Self.Arg) -> Self.Out:
        return _par_step[Self.V, Self.F, Self.K, Self.E](state^)


struct _ParAdopt[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate, E: Movable & Deinitable](OnceUnary):
    """Keep a started child's handle, then launch the next element."""
    var state: _ParBox[Self.V, Self.F, Self.K, Self.E]
    var node: ArcPointer[_ParNode]
    comptime Arg = Fiber[Self.K.Item, Self.E]
    comptime Out = IO[Self.K.Acc, Self.E]

    def __init__(out self, var state: _ParBox[Self.V, Self.F, Self.K, Self.E], var node: ArcPointer[_ParNode]):
        self.state = state^
        self.node = node^

    def call_once(deinit self, var fiber: Self.Arg) -> Self.Out:
        ref state = self.state[]
        # A closed owner refuses a child: its record completes canceled and its
        # program, with the announcing finalizer, never runs. Announce for it;
        # a child that already ran has announced, and announcing is idempotent.
        var refused = fiber._claim.record[].done()
        state.slots[state.position(self.node[].index)].fiber = Optional(fiber^)
        state.live += 1
        if refused:
            state.group[].finished(self.node^)
        return _par_step[Self.V, Self.F, Self.K, Self.E](self.state^)


def _par_step[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate, E: Movable & Deinitable](var state: _ParBox[V, F, K, E]) -> IO[K.Acc, E]:
    """One step on the parent fiber: launch the next element, finish, or wait."""
    comptime T = K.Item
    comptime assert RepeatableUnary[F] and _ErrorCompatible[E, F.Error]
    ref s = state[]
    if not s.stopping and not s.exhausted and s.live < s.limit and s.batch < _PAR_BATCH and not s.group[].arrived():
        var item = _next_optional[F.Arg](s.source)
        if not item:
            s.exhausted = True
        else:
            var index = s.next
            s.next += 1
            s.slots.append(_ParSlot[T, E]())
            var program: Optional[IO[T, E]] = None
            comptime if F.Error == Never:
                program = Optional(rebind_var[IO[T, E]](_unary_repeated_as[Never](s.function, item.take())))
            else:
                try:
                    program = Optional(rebind_var[IO[T, E]](_unary_repeated_as[E](s.function, item.take())))
                except error:
                    s.fail_at(index, error^)
            if program:
                var node = ArcPointer(_ParNode(index))
                var notice = _ParNotice(s.group.copy(), node.copy())
                var child = program.take()._finalized(_Finalizer[E](False, None, _Erased(notice^), _par_notice[E]))
                s.batch += 1
                return child^.start()._bind(_ParAdopt[V, F, K, E](state^, node^))
    s.batch = 0
    if s.live == 0 and (s.abandoned or not s.stopping and s.exhausted):
        return IO[K.Acc, E].pure(s.acc.take())
    return IO[_ParBox[V, F, K, E], E]._lifted(_ParWait[V, F, K, E](state^))._bind(_ParResume[V, F, K, E]())


struct _StartParCollect[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate, E: Movable & Deinitable](OnceUnary):
    """Enter the loop's masked region when the collection runs: the counterpart of `_StartCollect`."""
    var source: Self.V
    var function: Self.F
    var limit: Int
    comptime Arg = Poll[Self.E]
    comptime Out = IO[Self.K.Acc, Self.E]
    comptime Error = Self.E

    def __init__(out self, var source: Self.V, var function: Self.F, limit: Int):
        self.source = source^
        self.function = function^
        self.limit = limit

    def call_once(deinit self, var poll: Poll[Self.E]) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.E, Self.K.Error]
        var start = _start_as[Self.E, Self.K]()
        return _par_step[Self.V, Self.F, Self.K, Self.E](OwnedPointer(_ParState[Self.V, Self.F, Self.K, Self.E](self.source^, self.function^, self.limit, poll^, start^)))


def _par_loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate, E: Movable & Deinitable](limit: Int, var f: F, var source: V) -> IO[K.Acc, E]:
    """The one concurrent loop, unbounded or with a live limit."""
    if limit < 1:
        abort("AsyncPar: a traversal limit must be at least 1")
    return IO[K.Acc, E]._uncancelable(_StartParCollect[V, F, K, E](source^, f^, limit))


struct _ParCombine[F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable, E: Movable & Deinitable](OnceThunk):
    """AsyncPar's combination when it runs: build the right IO, then run both sides through `both`."""
    var function: Self.F
    var left: IO[Self.F.First, Self.E]
    var right: Self.R
    comptime Out = IO[Self.F.Out, Self.E]
    comptime Error = Self.R.Error

    def __init__(out self, var function: Self.F, var left: IO[Self.F.First, Self.E], var right: Self.R):
        self.function = function^
        self.left = left^
        self.right = right^

    def call_once(deinit self) raises Self.Error -> Self.Out:
        var right = rebind_var[IO[Self.F.Second, Self.E]](_thunk_once_as[Self.Error](self.right^))
        return self.left^.both(right^)._mapped(Tupled(self.function^))


struct AsyncPar[E: Movable & Deinitable](Applicative, _LimitedLoop, not Deinitable):
    """The concurrent applicative over IO, Cats Effect's `IO.Par`: `Async[E].Par`.

    A family dictionary over the same IO carriers as `Async[E]`, with no
    wrapper type; only the selected family differs, as `ValidationFamily`
    differs from `ResultFamily`. Combination runs both operands through
    `both`, and traversal runs every element as a child fiber of the running
    fiber with the policy of `both`. It deliberately is not a Monad: a
    dependent step cannot start before the value it depends on exists, so
    sequence those with `Async[E]`.

    Callbacks run on the running fiber in source order, when the IO runs.
    Results keep source order. The first element that ends unsuccessfully
    stops the others; every started child finishes before the IO completes,
    and the failure carries every error observed by then, in element order.
    The parent's cancellation is forwarded the same way. Elements not yet
    pulled are never started, and an empty source starts no fiber. Each
    element costs about one fiber start, so batch elements that wait or work
    for less than tens of microseconds.

    Parameters:
        E: The shared domain error.
    """
    comptime Element[V: Movable & Deinitable] = Async[Self.E].Element[V]
    comptime CarrierCompatible[V: Movable & Deinitable] = Async[Self.E].CarrierCompatible[V]
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Async[Self.E].MapCompatible[V, F]
    comptime CombineCompatible[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Async[Self.E].CombineCompatible[V, F, R]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Async[Self.E].Mapped[V, F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Async[Self.E].MapError[V, F]
    comptime Pure[A: Movable & Deinitable] = Async[Self.E].Pure[A]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Async[Self.E].Combined[V, F, R]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Async[Self.E].CombineError[V, F, R]
    comptime CollectCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Async[Self.E].CollectCompatible[V, F]
    comptime _LoopCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Async[Self.E]._LoopCompatible[V, F, K]
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Async[Self.E]._Looped[V, F, K]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Async[Self.E]._LoopError[V, F, K]

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        """Own an evaluated value in an IO, as `Async[E].pure` does.

        Parameters:
            A: The exact owned value type.

        Args:
            value: The value, consumed once.

        Returns:
            An IO producing the value.
        """
        return IO[A, Self.E].pure(value^)

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) -> Self.Mapped[V, F]:
        """Apply a callback to the success value, as `Async[E].map` does.

        Parameters:
            V: An IO in this family.
            F: A once-admitted owned callback with a compatible native error.

        Args:
            f: The callback, consumed.
            value: The IO, consumed.

        Returns:
            An IO whose failure includes the callback's error.
        """
        return Async[Self.E].map(f^, value^)

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var f: F, var left: V, var right: R) -> Self.Combined[V, F, R]:
        """Run both operands concurrently through `both`, then combine their values.

        Parameters:
            V: The left IO in this family.
            F: The once-admitted combiner of the left and right values.
            R: The once-admitted factory of the right IO.

        Args:
            f: The combiner, consumed.
            left: The left IO, consumed.
            right: The right factory, run when the IO runs, before both sides start.

        Returns:
            An IO of the combined value; failures keep left-before-right error order.
        """
        comptime assert Self.CombineCompatible[V, F, R]
        return IO[F.Out, Self.E]._deferred(_ParCombine[F, R, Self.E](f^, rebind_var[IO[F.First, Self.E]](left^), right^))

    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V) -> Self._Looped[V, F, K]:
        comptime assert Self._LoopCompatible[V, F, K]
        return _par_loop[V, F, K, Self.E](_PAR_UNBOUNDED, f^, source^)

    @staticmethod
    def _loop_limited[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](limit: Int, var f: F, var source: V) -> Self._Looped[V, F, K]:
        comptime assert Self._LoopCompatible[V, F, K]
        return _par_loop[V, F, K, Self.E](limit, f^, source^)


struct Async[E: Movable & Deinitable](Monad, ErrorRecovery, Defer, Raise, Temporal, Blocking, EvalOn, Parallel, not Deinitable):
    """The sequencing and recovery family of IO.

    Pipeline, tail_rec_m, traverse and attempt select it from an IO. Every
    operation returns an unopened IO; callbacks run once, when the program
    reaches them, and their errors become the IO's failure. Folds and loops
    run on the IO run loop in constant native stack. Callbacks must own their
    state: borrowed callback views are rejected, so pass a native function or
    an owned callable.

    Parameters:
        E: The exact domain error shared by every IO in this family.
    """
    comptime Par = AsyncPar[Self.E]
    """The concurrent applicative over the same IO carriers (Cats Effect's `IO.Par`)."""
    comptime Element[V: Movable & Deinitable] = downcast[V, Machine].Value
    comptime CarrierCompatible[V: Movable & Deinitable] = _IsIO[V, Self.E]
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.CarrierCompatible[V] and _Maps[Self.E, F]
    comptime BindCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.CarrierCompatible[V] and _Binds[Self.E, F]
    comptime CombineCompatible[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.CarrierCompatible[V] and _OnceBinaryAvailable[F] and _ErrorCompatible[Self.E, F.Error] and _Admitted[F] and _Defers[Self.E, R]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = IO[F.Out, Self.E]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Never
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = IO[downcast[F.Out, Machine].Value, Self.E]
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Never
    comptime Pure[A: Movable & Deinitable] = IO[A, Self.E]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = IO[F.Out, Self.E]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Never

    # Capabilities: each forwards to IO's own operation.
    comptime Family = Self
    comptime DelayCompatible[F: ThunkContract & Movable & Deinitable] = _OnceThunkAvailable[F] and _ErrorCompatible[Self.E, F.Error] and _Admitted[F]
    comptime Delayed[F: ThunkContract & Movable & Deinitable] = IO[_DelayValue[F.Out], Self.E]
    comptime DeferCompatible[F: ThunkContract & Movable & Deinitable] = _Defers[Self.E, F]
    comptime Deferred[F: ThunkContract & Movable & Deinitable] = IO[downcast[F.Out, Machine].Value, Self.E]
    comptime Error = Self.E
    comptime Raised[A: Movable & Deinitable] = IO[A, Self.E]
    comptime RegionPoll = _PollOf[Self.E]
    comptime Canceled = IO[NoneType, Self.E]
    comptime GuaranteeCompatible[V: Movable & Deinitable, Q: Movable & Deinitable] = _IsIO[V, Self.E] and Q == IO[NoneType, Self.E]
    comptime Guaranteed[V: Movable & Deinitable, Q: Movable & Deinitable] = V
    comptime OnCanceled[V: Movable & Deinitable, Q: Movable & Deinitable] = V
    comptime CaseCompatible[V: Movable & Deinitable, F: Movable & Deinitable] = _IsIO[V, Self.E] and _CaseFinalizer[F, Self.E]
    comptime CaseGuaranteed[V: Movable & Deinitable, F: Movable & Deinitable] = V
    comptime UncancelableCompatible[F: UnaryContract & Movable & Deinitable] = F.Arg == _PollOf[Self.E] and _IsIO[F.Out, Self.E] and _Maps[Self.E, F]
    comptime Uncanceled[F: UnaryContract & Movable & Deinitable] = IO[downcast[F.Out, Machine].Value, Self.E]
    comptime RestoreCompatible[V: Movable & Deinitable] = _IsIO[V, Self.E]
    comptime Restored[V: Movable & Deinitable] = V
    comptime Handle[T: Movable & Deinitable] = Fiber[T, Self.E]
    comptime StartCompatible[V: Movable & Deinitable] = _IsIO[V, Self.E]
    comptime Started[V: Movable & Deinitable] = IO[Fiber[downcast[V, Machine].Value, Self.E], Self.E]
    comptime Joined[T: Movable & Deinitable] = IO[Outcome[T, Self.E], Self.E]
    comptime Stopped = IO[NoneType, Self.E]
    comptime Forever[A: Movable & Deinitable] = IO[A, Self.E]
    comptime Ceded = IO[NoneType, Self.E]
    comptime Backgrounded[V: Movable & Deinitable] = Resource[Background[downcast[V, Machine].Value, Self.E], Self.E]
    comptime RefHandle[T: Movable & Deinitable] = Ref[T]
    comptime DeferredHandle[T: Copyable & Deinitable] = Deferred[T]
    comptime RefMade[T: Movable & Deinitable] = IO[Ref[T], Self.E]
    comptime DeferredMade[T: Copyable & Deinitable] = IO[Deferred[T], Self.E]
    comptime RefRead[T: Copyable & Deinitable] = IO[T, Self.E]
    comptime RefWritten = IO[NoneType, Self.E]
    comptime UpdateCompatible[T: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Arg == T and F.Out == T and F.Error == Never and _OnceUnaryAvailable[F] and _Admitted[F]
    comptime RefUpdated[T: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = IO[NoneType, Self.E]
    comptime ModifyCompatible[T: Movable & Deinitable, A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Arg == T and F.Out == Tuple[T, A] and F.Error == Never and _OnceUnaryAvailable[F] and _Admitted[F]
    comptime RefModified[T: Movable & Deinitable, A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = IO[A, Self.E]
    comptime DeferredCompleted = IO[Bool, Self.E]
    comptime DeferredRead[T: Copyable & Deinitable] = IO[T, Self.E]
    comptime Monotonic = IO[Instant, Self.E]
    comptime RealTime = IO[SystemTime, Self.E]
    comptime TimedCompatible[V: Movable & Deinitable] = _IsIO[V, Self.E]
    comptime Timed[V: Movable & Deinitable] = IO[Tuple[Duration, downcast[V, Machine].Value], Self.E]
    comptime Slept = IO[NoneType, Self.E]
    comptime TemporalCompatible[V: Movable & Deinitable] = _IsIO[V, Self.E]
    comptime TimedOut[V: Movable & Deinitable] = V
    comptime DelayedBy[V: Movable & Deinitable] = V
    comptime Waited[V: Movable & Deinitable] = V
    comptime BlockingCompatible[F: ThunkContract & Movable & Deinitable] = Self.DelayCompatible[F]
    comptime Blocked[F: ThunkContract & Movable & Deinitable] = IO[_DelayValue[F.Out], Self.E]
    comptime InterruptibleCompatible[F: BorrowCallContract & Movable & Deinitable] = F.Payload == Interruption and _OnceBorrowAvailable[F] and _ErrorCompatible[Self.E, F.Failure] and _Admitted[F]
    comptime Interrupted[F: BorrowCallContract & Movable & Deinitable] = IO[F.Result, Self.E]
    comptime Context = ExecutionContext
    # A where clause cannot evaluate the root-bound walk: IO.eval_on asserts it.
    comptime EvalOnCompatible[V: Movable & Deinitable] = _IsIO[V, Self.E]
    comptime EvaluatedOn[V: Movable & Deinitable] = V
    comptime StartedOn[V: Movable & Deinitable] = IO[Fiber[downcast[V, Machine].Value, Self.E], Self.E]
    comptime BackgroundedOn[V: Movable & Deinitable] = Resource[Background[downcast[V, Machine].Value, Self.E], Self.E]
    comptime CurrentContext = IO[Optional[ExecutionContext], Self.E]

    @staticmethod
    def delay[F: ThunkContract & Movable & Deinitable](var function: F) -> Self.Delayed[F]:
        """Evaluate a function when the IO reaches it; see IO.delay.

        Parameters:
            F: An owned once-callable, with error E or none.

        Args:
            function: The function, consumed.

        Returns:
            An IO producing the function's value.
        """
        comptime assert Self.DelayCompatible[F]
        return IO[_DelayValue[F.Out], Self.E]._deferred(_Delay[F, Self.E](function^))

    @staticmethod
    def defer[F: ThunkContract & Movable & Deinitable](var factory: F) -> Self.Deferred[F]:
        """Build an IO when it is reached; see IO.defer.

        Parameters:
            F: An owned once-callable returning an IO with error E.

        Args:
            factory: The factory, consumed.

        Returns:
            An IO running the program the factory builds.
        """
        comptime assert Self.DeferCompatible[F]
        return IO[downcast[F.Out, Machine].Value, Self.E]._deferred(factory^)

    @staticmethod
    def blocking[F: ThunkContract & Movable & Deinitable](var function: F) -> Self.Blocked[F]:
        """Run a blocking function on the root's blocking pool; see IO.blocking.

        Parameters:
            F: An owned once-callable, with error E or none.

        Args:
            function: The function, consumed.

        Returns:
            An IO producing the function's value; cancellation waits for it.
        """
        comptime assert Self.BlockingCompatible[F]
        return IO[_DelayValue[F.Out], Self.E]._blocking(function^)

    @staticmethod
    def interruptible[F: BorrowCallContract & Movable & Deinitable](var function: F) -> Self.Interrupted[F]:
        """Run an interruptible function on the root's blocking pool; see IO.interruptible.

        Parameters:
            F: An owned once-callable borrowing an Interruption, with error E or none.

        Args:
            function: The function, consumed.

        Returns:
            An IO producing the function's value, or canceled after it returns.
        """
        comptime assert Self.InterruptibleCompatible[F]
        return IO[F.Result, Self.E]._interruptible(function^)

    @staticmethod
    def raise_error[A: Movable & Deinitable](var error: Self.E) -> IO[A, Self.E]:
        """Fail with one ordinary error; see IO.raise_error.

        Parameters:
            A: The success type.

        Args:
            error: The error, consumed.

        Returns:
            An IO failing with an uncanceled failure holding the error.
        """
        return IO[A, Self.E].raise_error(error^)

    @staticmethod
    def canceled() -> IO[NoneType, Self.E]:
        """Request cancellation of the running program; see IO.canceled.

        Returns:
            A unit IO.
        """
        return IO[NoneType, Self.E].canceled()

    @staticmethod
    def guarantee[V: Movable & Deinitable, Q: Movable & Deinitable](var program: V, var finalizer: Q) -> V:
        """Run a finalizer after the program on every exit; see IO.guarantee.

        Parameters:
            V: An IO with error E.
            Q: IO[NoneType, E].

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            The guarded IO.
        """
        comptime assert Self.GuaranteeCompatible[V, Q]
        comptime T = downcast[V, Machine].Value
        return rebind_var[V](rebind_var[IO[T, Self.E]](program^).guarantee(rebind_var[IO[NoneType, Self.E]](finalizer^)))

    @staticmethod
    def on_cancel[V: Movable & Deinitable, Q: Movable & Deinitable](var program: V, var finalizer: Q) -> V:
        """Run a finalizer only if the program is canceled; see IO.on_cancel.

        Parameters:
            V: An IO with error E.
            Q: IO[NoneType, E].

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            The guarded IO.
        """
        comptime assert Self.GuaranteeCompatible[V, Q]
        comptime T = downcast[V, Machine].Value
        return rebind_var[V](rebind_var[IO[T, Self.E]](program^).on_cancel(rebind_var[IO[NoneType, Self.E]](finalizer^)))

    @staticmethod
    def guarantee_case[V: Movable & Deinitable, F: Movable & Deinitable](var program: V, var finalizer: F) -> V:
        """Run a finalizer built from the exact exit; see IO.guarantee_case.

        Parameters:
            V: An IO with error E.
            F: An owned once-callable borrowing ExitCase[E] and returning IO[NoneType, E].

        Args:
            program: The program, consumed.
            finalizer: The finalizer factory, consumed.

        Returns:
            The guarded IO.
        """
        comptime assert Self.CaseCompatible[V, F]
        comptime T = downcast[V, Machine].Value
        comptime B = downcast[F, BorrowCallContract & Movable & Deinitable]
        return rebind_var[V](rebind_var[IO[T, Self.E]](program^)._guarantee_case(rebind_var[B](finalizer^)))

    @staticmethod
    def uncancelable[F: UnaryContract & Movable & Deinitable](var body: F) -> Self.Uncanceled[F]:
        """Run a region masked; see IO.uncancelable.

        Parameters:
            F: An owned once-callable from Poll[E] to an IO with error E.

        Args:
            body: The region's factory, consumed.

        Returns:
            The masked IO.
        """
        comptime assert Self.UncancelableCompatible[F]
        return IO[downcast[F.Out, Machine].Value, Self.E]._uncancelable(body^)

    @staticmethod
    def restore[V: Movable & Deinitable](poll: _PollOf[Self.E], var program: V) -> V:
        """Run part of a region with the outer cancellation state; see IO.restore.

        Parameters:
            V: An IO with error E.

        Args:
            poll: The region's poll, borrowed.
            program: The program, consumed.

        Returns:
            The restored IO.
        """
        comptime assert Self.RestoreCompatible[V]
        return rebind_var[V](rebind_var[IO[downcast[V, Machine].Value, Self.E]](program^).restore(poll))

    @staticmethod
    def start[V: Movable & Deinitable](var program: V) -> Self.Started[V]:
        """Start the program as a fiber; see IO.start.

        Parameters:
            V: An IO with error E.

        Args:
            program: The program, consumed.

        Returns:
            An IO producing the fiber's handle.
        """
        comptime assert Self.StartCompatible[V]
        return rebind_var[IO[downcast[V, Machine].Value, Self.E]](program^).start()

    @staticmethod
    def join[T: Movable & Deinitable](var fiber: Fiber[T, Self.E]) -> IO[Outcome[T, Self.E], Self.E]:
        """Wait for a fiber and take its outcome; see Fiber.join.

        Parameters:
            T: The fiber's success type.

        Args:
            fiber: The handle, consumed.

        Returns:
            An IO producing the fiber's outcome.
        """
        return fiber^.join()

    @staticmethod
    def cancel[T: Movable & Deinitable](fiber: Fiber[T, Self.E]) -> IO[NoneType, Self.E]:
        """Cancel a fiber and wait for it; see Fiber.cancel.

        Parameters:
            T: The fiber's success type.

        Args:
            fiber: The handle, borrowed.

        Returns:
            A unit IO completing after the fiber terminates.
        """
        return fiber.cancel()

    @staticmethod
    def never[A: Movable & Deinitable]() -> IO[A, Self.E]:
        """Wait until canceled; see IO.never.

        Parameters:
            A: The success type.

        Returns:
            An IO that never produces a value.
        """
        return IO[A, Self.E].never()

    @staticmethod
    def cede() -> IO[NoneType, Self.E]:
        """Yield once; see IO.cede.

        Returns:
            A unit IO.
        """
        return IO[NoneType, Self.E].cede()

    @staticmethod
    def eval_on[V: Movable & Deinitable](var program: V, target: ExecutionContext) -> V:
        """Run the program on `target`; see IO.eval_on.

        Parameters:
            V: An IO with error E.

        Args:
            program: The program, consumed.
            target: The runtime or blocking pool to run on.

        Returns:
            An IO with the program's outcome.
        """
        comptime assert Self.EvalOnCompatible[V], "eval_on: an IO of this family"
        return rebind_var[V](rebind_var[IO[downcast[V, Machine].Value, Self.E]](program^).eval_on(target))

    @staticmethod
    def start_on[V: Movable & Deinitable](var program: V, target: ExecutionContext) -> Self.StartedOn[V]:
        """Start the program as a fiber whose work runs on `target`; see IO.start_on.

        Parameters:
            V: An IO with error E.

        Args:
            program: The program, consumed.
            target: The runtime or blocking pool to run on.

        Returns:
            An IO producing the fiber's handle.
        """
        comptime assert Self.EvalOnCompatible[V], "start_on: an IO of this family"
        return rebind_var[IO[downcast[V, Machine].Value, Self.E]](program^).start_on(target)

    @staticmethod
    def background[V: Movable & Deinitable](var program: V) -> Self.Backgrounded[V]:
        """Run the program as a fiber while a resource is in use; see IO.background.

        Parameters:
            V: An IO with error E.

        Args:
            program: The program, consumed.

        Returns:
            The resource, whose value is the fiber's `Background` handle.
        """
        comptime assert Self.StartCompatible[V]
        return rebind_var[IO[downcast[V, Machine].Value, Self.E]](program^).background()

    @staticmethod
    def background_on[V: Movable & Deinitable](var program: V, target: ExecutionContext) -> Self.BackgroundedOn[V]:
        """Run the program on `target` as a fiber while a resource is in use; see IO.background_on.

        Parameters:
            V: An IO with error E.

        Args:
            program: The program, consumed.
            target: The runtime or blocking pool to run on.

        Returns:
            The resource, whose value is the fiber's `Background` handle.
        """
        comptime assert Self.EvalOnCompatible[V], "background_on: an IO of this family"
        return rebind_var[IO[downcast[V, Machine].Value, Self.E]](program^).background_on(target)

    @staticmethod
    def execution_context() -> IO[Optional[ExecutionContext], Self.E]:
        """The running program's context; see IO.execution_context.

        Returns:
            An IO producing the context, or None.
        """
        return IO[Optional[ExecutionContext], Self.E].execution_context()

    @staticmethod
    def make_ref[T: Movable & Deinitable](var value: T) -> IO[Ref[T], Self.E]:
        """Allocate a Ref when the IO reaches it.

        Parameters:
            T: The state type.

        Args:
            value: The initial state, consumed.

        Returns:
            An IO producing a new Ref on each run.
        """
        return IO[Ref[T], Self.E].delay(_NewRef[T](value^))

    @staticmethod
    def make_deferred[T: Copyable & Deinitable]() -> IO[Deferred[T], Self.E]:
        """Allocate an empty Deferred when the IO reaches it.

        Parameters:
            T: The value type.

        Returns:
            An IO producing a new Deferred on each run.
        """
        return IO[Deferred[T], Self.E].delay(_NewDeferred[T]())

    @staticmethod
    def get_ref[T: Copyable & Deinitable](cell: Ref[T]) -> IO[T, Self.E]:
        """Copy a Ref's state; see Ref.get.

        Parameters:
            T: The state type.

        Args:
            cell: The Ref, borrowed.

        Returns:
            An IO producing the copy.
        """
        return cell.get[Self.E]()

    @staticmethod
    def set_ref[T: Movable & Deinitable](cell: Ref[T], var value: T) -> IO[NoneType, Self.E]:
        """Replace a Ref's state; see Ref.set.

        Parameters:
            T: The state type.

        Args:
            cell: The Ref, borrowed.
            value: The replacement, consumed.

        Returns:
            A unit IO.
        """
        return cell.set[Self.E](value^)

    @staticmethod
    def update_ref[T: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](cell: Ref[T], var function: F) -> IO[NoneType, Self.E]:
        """Transform a Ref's state atomically; see Ref.update.

        Parameters:
            T: The state type.
            F: An owned non-raising transformation from T to T.

        Args:
            cell: The Ref, borrowed.
            function: The transformation, consumed.

        Returns:
            A unit IO.
        """
        comptime assert F.Arg == T and F.Out == T and F.Error == Never and _OnceUnaryAvailable[F] and _Admitted[F], "update_ref: the transformation must own its state and map T to T without raising"
        return cell.update[Self.E](function^)

    @staticmethod
    def modify_ref[T: Movable & Deinitable, A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](cell: Ref[T], var function: F) -> IO[A, Self.E]:
        """Consume and replace a Ref's state atomically; see Ref.modify.

        Parameters:
            T: The state type.
            A: The result type.
            F: An owned non-raising transformation from T to (T, A).

        Args:
            cell: The Ref, borrowed.
            function: The transformation, consumed.

        Returns:
            An IO producing A.
        """
        comptime assert F.Arg == T and F.Out == Tuple[T, A] and F.Error == Never and _OnceUnaryAvailable[F] and _Admitted[F], "modify_ref: the transformation must own its state and map T to (T, A) without raising"
        return cell.modify[Self.E, A](function^)

    @staticmethod
    def complete_deferred[T: Copyable & Deinitable](deferred: Deferred[T], var value: T) -> IO[Bool, Self.E]:
        """Assign a Deferred once; see Deferred.complete.

        Parameters:
            T: The value type.

        Args:
            deferred: The Deferred, borrowed.
            value: The value, consumed.

        Returns:
            An IO producing whether this completion won.
        """
        return deferred.complete[Self.E](value^)

    @staticmethod
    def get_deferred[T: Copyable & Deinitable](deferred: Deferred[T]) -> IO[T, Self.E]:
        """Wait for a Deferred's value; see Deferred.get.

        Parameters:
            T: The value type.

        Args:
            deferred: The Deferred, borrowed.

        Returns:
            An IO producing a copy of the value.
        """
        return deferred.get[Self.E]()

    @staticmethod
    def monotonic() -> IO[Instant, Self.E]:
        """Read the inherited clock; see IO.monotonic.

        Returns:
            An IO producing the current Instant.
        """
        return IO[Instant, Self.E].monotonic()

    @staticmethod
    def real_time() -> IO[SystemTime, Self.E]:
        """Read the inherited wall clock; see IO.real_time.

        Returns:
            An IO producing the current SystemTime.
        """
        return IO[SystemTime, Self.E].real_time()

    @staticmethod
    def timed[V: Movable & Deinitable](var program: V) -> Self.Timed[V]:
        """Measure a program; see IO.timed.

        Parameters:
            V: An IO with error E.

        Args:
            program: The program, consumed.

        Returns:
            An IO producing the elapsed Duration with the value.
        """
        comptime assert Self.TimedCompatible[V], "timed: the program must be an IO with error E"
        return rebind_var[IO[downcast[V, Machine].Value, Self.E]](program^).timed()

    @staticmethod
    def sleep(duration: Duration) -> IO[NoneType, Self.E]:
        """Wait for a duration; see IO.sleep.

        Args:
            duration: The checked relative duration.

        Returns:
            A unit IO.
        """
        return IO[NoneType, Self.E].sleep(duration)

    @staticmethod
    def timeout_to[V: Movable & Deinitable](var program: V, duration: Duration, var fallback: V) -> V:
        """Fall back after a duration; see IO.timeout_to.

        Parameters:
            V: An IO with error E.

        Args:
            program: The program, consumed.
            duration: The checked relative duration.
            fallback: The fallback, consumed.

        Returns:
            An IO with the program's or the fallback's outcome.
        """
        comptime assert Self.TemporalCompatible[V], "timeout_to: the program must be an IO with error E"
        comptime P = IO[downcast[V, Machine].Value, Self.E]
        return rebind_var[V](rebind_var[P](program^).timeout_to(duration, rebind_var[P](fallback^)))

    @staticmethod
    def timeout_after[V: Movable & Deinitable](var program: V, duration: Duration, var fallback: V) -> V:
        """Fall back by first terminal outcome; see IO.timeout_after.

        Parameters:
            V: An IO with error E.

        Args:
            program: The program, consumed.
            duration: The checked relative duration.
            fallback: The fallback, consumed.

        Returns:
            An IO with the program's or the fallback's outcome.
        """
        comptime assert Self.TemporalCompatible[V], "timeout_after: the program must be an IO with error E"
        comptime P = IO[downcast[V, Machine].Value, Self.E]
        return rebind_var[V](rebind_var[P](program^).timeout_after(duration, rebind_var[P](fallback^)))

    @staticmethod
    def timeout[V: Movable & Deinitable](var program: V, duration: Duration, var error: Self.E) -> V:
        """Fail with an error after a duration; see IO.timeout.

        Parameters:
            V: An IO with error E.

        Args:
            program: The program, consumed.
            duration: The checked relative duration.
            error: The domain error raised on timeout, consumed.

        Returns:
            An IO with the program's outcome or the error.
        """
        comptime assert Self.TemporalCompatible[V], "timeout: the program must be an IO with error E"
        comptime P = IO[downcast[V, Machine].Value, Self.E]
        return rebind_var[V](rebind_var[P](program^).timeout(duration, error^))

    @staticmethod
    def delay_by[V: Movable & Deinitable](var program: V, duration: Duration) -> V:
        """Sleep, then run the program; see IO.delay_by.

        Parameters:
            V: An IO with error E.

        Args:
            program: The program, consumed.
            duration: The checked relative duration.

        Returns:
            An IO with the program's outcome.
        """
        comptime assert Self.TemporalCompatible[V], "delay_by: the program must be an IO with error E"
        comptime P = IO[downcast[V, Machine].Value, Self.E]
        return rebind_var[V](rebind_var[P](program^).delay_by(duration))

    @staticmethod
    def and_wait[V: Movable & Deinitable](var program: V, duration: Duration) -> V:
        """Run the program, then sleep; see IO.and_wait.

        Parameters:
            V: An IO with error E.

        Args:
            program: The program, consumed.
            duration: The checked relative duration.

        Returns:
            An IO with the program's value after the sleep.
        """
        comptime assert Self.TemporalCompatible[V], "and_wait: the program must be an IO with error E"
        comptime P = IO[downcast[V, Machine].Value, Self.E]
        return rebind_var[V](rebind_var[P](program^).and_wait(duration))

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        """Own an evaluated value in an IO.

        Parameters:
            A: The exact owned value type, retaining native origins.

        Args:
            value: The value, consumed once.

        Returns:
            An IO producing the value.
        """
        return IO[A, Self.E].pure(value^)

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) -> Self.Mapped[V, F]:
        """Apply a callback to the success value when the IO reaches it.

        Parameters:
            V: An IO in this family.
            F: A once-admitted owned callback with a compatible native error.

        Args:
            f: The callback, consumed.
            value: The IO, consumed.

        Returns:
            An IO whose failure includes the callback's error. Failure and
            cancellation bypass the callback.
        """
        comptime assert Self.MapCompatible[V, F]
        return rebind_var[IO[Self.Element[V], Self.E]](value^)._mapped(f^)

    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) -> Self.Bound[V, F]:
        """Continue with the IO a callback builds from the success value.

        Parameters:
            V: An IO in this family.
            F: A once-admitted owned callback returning an IO with the same error.

        Args:
            f: The callback, consumed; it runs after success and an entry checkpoint.
            value: The IO, consumed.

        Returns:
            An IO running both in sequence.
        """
        comptime assert Self.BindCompatible[V, F]
        return rebind_var[IO[Self.Element[V], Self.E]](value^)._bind(f^)

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var f: F, var left: V, var right: R) -> Self.Combined[V, F, R]:
        """Run the left IO, build and run the right, then combine their values.

        Parameters:
            V: The left IO in this family.
            F: The once-admitted combiner of the left and right values.
            R: The once-admitted factory of the right IO.

        Args:
            f: The combiner, consumed.
            left: The left IO, consumed.
            right: The right factory, run only after left succeeds.

        Returns:
            Sequential composition; use both for concurrent children.
        """
        comptime assert Self.CombineCompatible[V, F, R]
        return rebind_var[IO[Self.Element[V], Self.E]](left^)._bind(_Combine[F, R, Self.E](f^, right^))

    comptime _FoldCompatible[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator] = (RepeatableUnary[P] and RepeatableBinary[F] and P.Arg == _Source[V].Element and P.Out == F.Second and F.First == K.Acc and Self.CarrierCompatible[F.Out] and Self.Element[F.Out] == K.Acc and _ErrorCompatible[Self.E, P.Error] and _ErrorCompatible[Self.E, F.Error] and _Admitted[P] and _Admitted[F]) if conforms_to(V, Iterator) or conforms_to(V, IterableOwned) else False
    comptime _Folded[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator] = IO[K.Acc, Self.E]
    comptime _FoldError[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator] = Never
    @staticmethod
    def _fold[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator](var prepare: P, var step: F, var initial: K.Acc, var source: V) -> Self._Folded[V, P, F, K]:
        comptime assert Self._FoldCompatible[V, P, F, K]
        return IO[K.Acc, Self.E]._deferred(_StartFold[V, P, F, K, Self.E](source^, prepare^, step^, initial^))

    comptime CollectCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.CarrierCompatible[F.Out] and RepeatableUnary[F] and _ErrorCompatible[Self.E, F.Error] and _Admitted[F]
    comptime _LoopCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = (Self.CollectCompatible[V, F] and Self.Element[F.Out] == K.Item and _Source[V].Element == F.Arg and _ErrorCompatible[Self.E, K.Error]) if conforms_to(V, Iterator) or conforms_to(V, IterableOwned) else False
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = IO[K.Acc, Self.E]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Never
    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V) -> Self._Looped[V, F, K]:
        comptime assert Self._LoopCompatible[V, F, K]
        return IO[K.Acc, Self.E]._deferred(_StartCollect[V, F, K, Self.E](source^, f^))

    comptime Failure = EffectFailure[Self.E]
    comptime _ErrorCarrier[V: Movable & Deinitable] = Self.CarrierCompatible[V]
    comptime _Handles[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = (Self.Element[V] == Self.Element[H.Out] and H.Arg == Self.Failure and _Maps[Self.E, H]) if Self.CarrierCompatible[V] and Self.CarrierCompatible[H.Out] else False
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = IO[Self.Element[V], Self.E]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Never
    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) -> Self.Handled[V, H]:
        """Recover an ordinary failure with the IO a handler builds.

        Parameters:
            V: An IO in this family.
            H: A once-admitted owned handler of EffectFailure[E], keeping the value type.

        Args:
            handler: The handler, consumed; cancellation bypasses it.
            source: The IO, consumed.

        Returns:
            An IO retaining full ordered errors and the cancellation flag.
        """
        comptime assert Self._Handles[V, H]
        return rebind_var[IO[Self.Element[V], Self.E]](source^)._recover(handler^)


# ===------------------------------------------------------------------=== #
# Resource: here beside IO, since IO.background returns one; the
# module graph stays acyclic. `io_resource` re-exports it.
# ===------------------------------------------------------------------=== #


comptime _ScopedPoll[T: Movable & Deinitable, E: Movable & Deinitable] = def(mut _Erased, T, IOContext[E]) thin -> Step[_Erased, E]


struct _ErasedScoped[T: Movable & Deinitable, E: Movable & Deinitable](ScopedMachine):
    """Poll a scoped body of hidden type under the scope's loan, boxing its value."""
    comptime Input = Self.T
    comptime Value = _Erased
    comptime Error = Self.E
    var _body: _Erased
    var _poll: _ScopedPoll[Self.T, Self.E]

    def __init__[U: ScopedMachine](out self, var body: U):
        def poll(mut body: _Erased, value: Self.T, context: IOContext[Self.E]) -> Step[_Erased, Self.E]:
            comptime assert U.Input == Self.T and U.Error == Self.E
            return _box_step(rebind_var[Step[U.Value, Self.E]](body.pointer[U]()[].poll(rebind[U.Input](value), rebind[IOContext[U.Error]](context))))

        comptime assert U.Input == Self.T and U.Error == Self.E
        self._body = _Erased(body^)
        self._poll = poll

    def poll[p: ImmOrigin](mut self, ref[p] value: Self.T, context: IOContext[Self.E]) -> Step[_Erased, Self.E]:
        return self._poll(self._body, value, context)


comptime _UsePlan[T: Movable & Deinitable, E: Movable & Deinitable] = def(var _Erased, var _ErasedScoped[T, E]) thin -> IO[_Erased, E]

# A body or release factory borrows the resource and returns an IO with the
# resource's error; the IO cannot retain the loan.
comptime _Factory[T: Movable & Deinitable, E: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = F.Payload == T and _OnceBorrowAvailable[F] and _ErrorCompatible[E, F.Failure] and _Admitted[F]
comptime _Joins[E: Movable & Deinitable, R: AnyType] = (downcast[R, _AsyncResourceType].Plan.Error == E) if conforms_to(R, _AsyncResourceType) else False


struct Resource[T: Movable & Deinitable, E: Movable & Deinitable](ResourcePlan, _AsyncResourceType):
    """A resource acquired before and released after each use, as an IO.

    `use` acquires masked, lends the resource to a body factory, runs the IO it
    builds, then releases masked with the exact exit. Releases run in reverse
    acquisition order and their errors follow the body's. Bodies and release
    factories borrow the resource and cannot retain it in the IO they return.

    Parameters:
        T: The owned resource value, lent during use.
        E: The exact domain error of acquisition, use and release.
    """
    comptime Value = Self.T
    comptime Error = Self.E
    comptime Plan = Self
    comptime _Used[U: ScopedMachine] = IO[U.Value, Self.E]
    var _plan: _Erased
    var _use_plan: _UsePlan[Self.T, Self.E]

    def __init__[P: ResourcePlan](out self, var plan: P):
        """Erase a typed plan; its type fixes every later cast of the box."""
        def use_plan(var plan: _Erased, var body: _ErasedScoped[Self.T, Self.E]) -> IO[_Erased, Self.E]:
            comptime assert P.Value == Self.T and P.Error == Self.E
            return IO[_Erased, Self.E]._lifted(plan^.take[P]()._use(body^))

        comptime assert P.Value == Self.T and P.Error == Self.E
        self._plan = _Erased(plan^)
        self._use_plan = use_plan

    def __init__(out self, *, var _plan: _Erased, _use_plan: _UsePlan[Self.T, Self.E]):
        self._plan = _plan^
        self._use_plan = _use_plan

    def _into_plan(deinit self) -> Self:
        return Self(_plan=self._plan^, _use_plan=self._use_plan)

    def _use[U: ScopedMachine](deinit self, var body: U) -> IO[U.Value, Self.E]:
        var boxed = self._use_plan(self._plan^, _ErasedScoped[Self.T, Self.E](body^))
        return boxed^._mapped(_Unbox[U.Value]())

    @staticmethod
    def make[F: BorrowCallContract & Movable & Deinitable](var acquire: IO[Self.T, Self.E], var release: F) -> Self where _Factory[Self.T, Self.E, F] and _IsIO[F.Result, Self.E] and downcast[F.Result, Machine].Value == NoneType:
        """Acquire with an IO; release with the IO a factory builds from the borrowed resource.

        Parameters:
            F: A once-admitted owned factory borrowing T and returning IO[NoneType, E].

        Args:
            acquire: The acquisition, run masked.
            release: The release factory, run masked after each use.

        Returns:
            An unopened resource; a failed acquisition runs no release.
        """
        return Self(_acquire_release(acquire^, _ScopedBuild[F, Self.E](release^)))

    @staticmethod
    def make(var acquire: IO[Self.T, Self.E], release: def(Self.T) thin -> IO[NoneType, Self.E]) -> Self:
        """Acquire with an IO; release with a native function of the borrowed resource."""
        return Self.make(acquire^, NativeBorrow[Self.T, IO[NoneType, Self.E], Never, def(Self.T) thin -> IO[NoneType, Self.E], False](release))

    @staticmethod
    def make_case[C: CleanupMachine](var acquire: IO[Self.T, Self.E], var release: C) -> Self where C.Input == Self.T and C.Error == Self.E:
        """Acquire with an IO; release with a machine that sees the exact exit.

        The Cats Effect counterpart is Resource.makeCase. The release borrows
        the resource and the body's ExitCase on each poll and may suspend.

        Parameters:
            C: A cleanup machine borrowing T, with error E.

        Args:
            acquire: The acquisition, run masked.
            release: The release, run masked after each use.

        Returns:
            An unopened resource; a failed acquisition runs no release.
        """
        return Self(_Acquire(acquire^, release^))

    @staticmethod
    def pure(var value: Self.T) -> Self:
        """Own a value as a resource with nothing to release.

        Args:
            value: The resource, moved in and lent to each use.

        Returns:
            A resource that acquires the value and releases nothing.
        """
        return _PureFactory[Self.T, Self.E]().call(value^)

    def use[F: BorrowCallContract & Movable & Deinitable](deinit self, var body: F) -> IO[downcast[F.Result, Machine].Value, Self.E] where _Factory[Self.T, Self.E, F] and _IsIO[F.Result, Self.E]:
        """Acquire, build the body's IO from the borrowed resource, run it, then release.

        Parameters:
            F: A once-admitted owned factory borrowing T and returning an IO.

        Args:
            body: The factory, called once after acquisition.

        Returns:
            An IO owning acquisition, body and release; release errors follow body errors.
        """
        return self^._use(_ScopedBuild[F, Self.E](body^))

    def use_scoped[U: ScopedMachine](deinit self, var body: U) -> IO[U.Value, Self.E] where U.Input == Self.T and U.Error == Self.E:
        """Acquire, poll a body with a fresh loan of the resource each poll, then release.

        Use this when work that suspends must keep using a move-only resource:
        an IO built by use cannot retain the resource across suspensions.

        Parameters:
            U: A scoped machine borrowing T, with error E.

        Args:
            body: The body, polled until it completes.

        Returns:
            An IO owning acquisition, body and release; release errors follow body errors.
        """
        return self^._use(body^)

    def use[U: Movable & Deinitable, //](deinit self, body: def(Self.T) thin -> IO[U, Self.E]) -> IO[U, Self.E]:
        """Use the resource through a native function."""
        return self^.use(NativeBorrow[Self.T, IO[U, Self.E], Never, def(Self.T) thin -> IO[U, Self.E], False](body))

    def flat_map[F: BorrowCallContract & Movable & Deinitable](deinit self, var f: F) -> Resource[downcast[F.Result, _AsyncResourceType].Plan.Value, Self.E] where _Factory[Self.T, Self.E, F] and _Joins[Self.E, F.Result]:
        """Acquire a dependent resource from the borrowed one; release it first.

        Parameters:
            F: A once-admitted owned factory borrowing T and returning a Resource.

        Args:
            f: The factory, called after this resource's acquisition.

        Returns:
            A resource exposing the dependent value while owning both releases.
        """
        return self^._joined(f^)

    def flat_map[U: Movable & Deinitable, //](deinit self, f: def(Self.T) thin -> Resource[U, Self.E]) -> Resource[U, Self.E]:
        """Acquire a dependent resource through a native function."""
        return self^._joined(NativeBorrow[Self.T, Resource[U, Self.E], Never, def(Self.T) thin -> Resource[U, Self.E], False](f))

    def _joined[F: BorrowCallContract & Movable & Deinitable](deinit self, var f: F) -> Resource[downcast[F.Result, _AsyncResourceType].Plan.Value, Self.E]:
        comptime assert _Factory[Self.T, Self.E, F] and _Joins[Self.E, F.Result]
        return Resource[downcast[F.Result, _AsyncResourceType].Plan.Value, Self.E](_ResourceJoin(self^, f^))

    def map[F: BorrowCallContract & Movable & Deinitable](deinit self, var f: F) -> Resource[F.Result, Self.E] where _Factory[Self.T, Self.E, F]:
        """Project an owned value from the borrowed resource, keeping its release.

        Parameters:
            F: A once-admitted owned projection borrowing T.

        Args:
            f: The projection, called after acquisition.

        Returns:
            A resource of the projected value; the projection cannot retain the loan.
        """
        return rebind_var[Resource[F.Result, Self.E]](self^._joined(_MapScopeFactory[F, Self.E, _PureFactory[F.Result, Self.E]](f^)))

    def map[R: Movable & Deinitable, //](deinit self, f: def(Self.T) thin -> R) -> Resource[R, Self.E]:
        """Project an owned value through a native function."""
        return self^.map(NativeBorrow[Self.T, R, Never, def(Self.T) thin -> R, False](f))


@fieldwise_init
struct _PureFactory[T: Movable & Deinitable, E: Movable & Deinitable](Unary, Defaultable):
    """Own a value as a resource whose release does nothing; map projects through it."""
    comptime Arg = Self.T
    comptime Out = Resource[Self.T, Self.E]

    def call(self, var value: Self.T) -> Self.Out:
        var unit: NoneType = None
        return Self.Out(_acquire_release(_pure[Self.E](value^), _ProgramUse[_Pure[NoneType, Self.E], Self.T](_pure[Self.E](unit))))
