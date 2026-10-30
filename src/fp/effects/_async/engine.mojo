"""The private IO run loop: flat programs evaluated iteratively over canonical owners.

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
from std.memory import OwnedPointer, MaybeUninit
from std.os import abort
from fp.algebra.protocols import Monad, ErrorRecovery, _Accumulate, _LiveAccumulator, _AccumulatePair, _start_as
from fp.callables.protocols import UnaryContract, BinaryContract, ThunkContract, BorrowCallContract, OnceUnary, OnceThunk, MutableBinary
from fp.callables.invoke import _OnceUnaryAvailable, _OnceBinaryAvailable, _OnceThunkAvailable, _OnceBorrowAvailable, RepeatableUnary, RepeatableBinary
from fp.callables._receiver import _unary_once_as, _thunk_once_as, _borrow_once_as, _unary_repeated_as, _binary_repeated_as
from fp.callables._binding import _BindFirst
from fp.callables._identity import Identity
from fp.callables._views import _BorrowedView
from fp.callables.native import NativeUnary, _NativeThunk, _NativeOwnedArg
from fp.algebra._outcomes import _Materialize
from fp.iteration._advance import _Source, _source, _next_optional
from fp._internal.erased import _Erased
from fp._internal.errors import _ErrorCompatible
from fp.data import Result, Ok, Err, NonEmptyList
from fp.effects import IOContext, Outcome, EffectFailure, ExitCase
from fp.effects.outcomes import _failure_as, _finish, _ExitState
from fp.effects._io_core import _settle, IOContract, canceled as _cancel_request
from fp.effects.protocols import ReaderAction
from fp.effects.finalization import Poll as _SyncPoll
from .kernel import Machine, Step, Wait, _Slot, _tick, Sleep as _Sleep
from .time import Duration
from .children import both as _both
from .racing import RaceResult, race as _race, race_first as _race_first, timeout_after as _timeout_after, timeout_to as _timeout_to
from .io import EvalIO as _EvalIO
from .callbacks import Callback as _Callback, Completion, _CallbackUnit
from .family import Machine as _FamilyMachine
from .erased import _ErasedMachine
from .finalization import Poll

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

# Interpreter transitions per poll before yielding; Pass 8b makes this a policy.
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
        program^.install_into(self)

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
                _ = _tick(self.leaf.value(), context)
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


def _loop_at[E: Movable & Deinitable](loop: MutOpaquePointer[_]) -> ref[loop.origin] _RunLoop[E]:
    # The run loop lends its own address; the engine fixes this type.
    return loop.unsafe_bitcast[_RunLoop[E]]()[]


struct _Boxed[P: Machine, E: Movable & Deinitable](Machine):
    """Present a typed leaf to the run loop with its success value boxed."""
    comptime Value = _Erased
    comptime Error = Self.E
    var program: Self.P

    def __init__(out self, var program: Self.P):
        self.program = program^

    def poll(mut self, context: IOContext[Self.E]) -> Step[_Erased, Self.E]:
        comptime assert Self.P.Error == Self.E
        var step = self.program.poll(rebind[IOContext[Self.P.Error]](context))
        if not step._completed:
            return Step[_Erased, Self.E].pending(step^._waiting())
        var protected = step._protected_success
        var outcome = rebind_var[Outcome[Self.P.Value, Self.E]](step^._outcome())
        if outcome and outcome.value().is_ok():
            var boxed: Outcome[_Erased, Self.E] = Optional(Result[_Erased, EffectFailure[Self.E]](Ok(_Erased(outcome.take()._take_ok()))))
            return Step[_Erased, Self.E]._make(Optional(boxed^), Wait(), protected)
        var failed = _failure_as[_Erased](outcome^)
        return Step[_Erased, Self.E]._make(Optional(failed^), Wait(), protected)


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


struct IO[T: Movable & Deinitable, E: Movable & Deinitable](_FamilyMachine):
    """An asynchronous effect producing T or failing with E, run by the private engine.

    An IO runs once. Unopened values may be dropped; disposal is iterative.
    """
    comptime Family = Async[Self.E]
    comptime Value = Self.T
    comptime Error = Self.E
    var _program: _Program[Self.E]
    var _loop: MaybeUninit[OwnedPointer[_RunLoop[Self.E]]]
    var _entered: Bool

    def __init__(out self, var program: _Program[Self.E]):
        self._program = program^
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
        return Self(_Program[Self.E](_Head[Self.E](_PURE, _Erased(value^))))

    @staticmethod
    def raise_error(var error: Self.E) -> Self:
        return Self(_Program[Self.E](_Head[Self.E](_FAIL, _Erased(EffectFailure[Self.E](NonEmptyList(error^), False)))))

    # Public operations state admission in their signatures and delegate to
    # private forms, which generic code calls after its own checks.
    @staticmethod
    def lift[P: Machine](var machine: P) -> Self where P.Value == Self.T and P.Error == Self.E:
        """Run a custom machine as one step of an IO."""
        return Self._lifted(machine^)

    @staticmethod
    def _lifted[P: Machine](var machine: P) -> Self:
        comptime assert P.Value == Self.T and P.Error == Self.E
        return Self(_Program[Self.E](_Head[Self.E](_LEAF, _Erased(_Leaf[Self.E](_Boxed[P, Self.E](machine^))))))

    @staticmethod
    def delay[F: ThunkContract & Movable & Deinitable](var function: F) -> Self where F.Out == Self.T and _OnceThunkAvailable[F] and _ErrorCompatible[Self.E, F.Error] and _Admitted[F]:
        """Evaluate a synchronous function when the IO reaches it.

        Its error becomes this IO's failure. Use defer when the function builds an IO.
        """
        return Self._deferred(_Delay[F, Self.E](function^))

    @staticmethod
    def delay(function: def() thin -> Self.T) -> Self where not conforms_to(Self.T, RegisterPassable):
        """Evaluate a native function when the IO reaches it."""
        return Self._deferred(_Delay[_NativeThunk[Self.T, Never, def() thin -> Self.T, False], Self.E](_NativeThunk[Self.T, Never, def() thin -> Self.T, False](function)))

    @staticmethod
    def delay(function: def() thin -> _NativeOwnedArg[Self.T]) -> Self where conforms_to(Self.T, RegisterPassable):
        """Evaluate a native function when the IO reaches it."""
        return Self._deferred(_Delay[_NativeThunk[Self.T, Never, def() thin -> _NativeOwnedArg[Self.T], False], Self.E](_NativeThunk[Self.T, Never, def() thin -> _NativeOwnedArg[Self.T], False](function)))

    @staticmethod
    def delay[X: Movable & Deinitable, //](function: def() raises X thin -> Self.T) -> Self where _ErrorCompatible[Self.E, X] and not conforms_to(Self.T, RegisterPassable):
        """Evaluate a raising native function; its error becomes the failure."""
        return Self._deferred(_Delay[_NativeThunk[Self.T, X, def() raises X thin -> Self.T, True], Self.E](_NativeThunk[Self.T, X, def() raises X thin -> Self.T, True](function)))

    @staticmethod
    def delay[X: Movable & Deinitable, //](function: def() raises X thin -> _NativeOwnedArg[Self.T]) -> Self where _ErrorCompatible[Self.E, X] and conforms_to(Self.T, RegisterPassable):
        """Evaluate a raising native function; its error becomes the failure."""
        return Self._deferred(_Delay[_NativeThunk[Self.T, X, def() raises X thin -> _NativeOwnedArg[Self.T], True], Self.E](_NativeThunk[Self.T, X, def() raises X thin -> _NativeOwnedArg[Self.T], True](function)))

    @staticmethod
    def defer[F: ThunkContract & Movable & Deinitable](var factory: F) -> Self where _Defers[Self.E, F] and F.Out == Self:
        """Build the IO when it is reached, so recursive programs build lazily."""
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
        return Self(_Program[Self.E](_Head[Self.E](_DEFER, _Erased(factory^), invoke)))

    def flat_map[F: UnaryContract & Movable & Deinitable](deinit self, var f: F) -> IO[downcast[F.Out, Machine].Value, Self.E] where F.Arg == Self.T and _Binds[Self.E, F]:
        """Continue with the IO a callback builds from the success value."""
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
        return IO[U, Self.E](program^)

    def map[F: UnaryContract & Movable & Deinitable](deinit self, var f: F) -> IO[F.Out, Self.E] where F.Arg == Self.T and _Maps[Self.E, F]:
        """Apply a callback to the success value; failure and cancellation bypass it."""
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
        return IO[F.Out, Self.E](program^)

    def handle_error_with[H: UnaryContract & Movable & Deinitable](deinit self, var handler: H) -> Self where H.Arg == EffectFailure[Self.E] and _Maps[Self.E, H] and H.Out == Self:
        """Recover an ordinary failure with the IO a handler builds; cancellation bypasses it."""
        return self^._recover(handler^)

    def handle_error_with(deinit self, handler: def(var EffectFailure[Self.E]) thin -> Self) -> Self:
        """Recover an ordinary failure with a native handler."""
        return self^._recover(NativeUnary[EffectFailure[Self.E], Self, Never, def(var EffectFailure[Self.E]) thin -> Self, False](handler))

    def handle_error_with[X: Movable & Deinitable, //](deinit self, handler: def(var EffectFailure[Self.E]) raises X thin -> Self) -> Self where _ErrorCompatible[Self.E, X]:
        """Recover with a raising native handler; its error replaces the failure."""
        return self^._recover(NativeUnary[EffectFailure[Self.E], Self, X, def(var EffectFailure[Self.E]) raises X thin -> Self, True](handler))

    def attempt(deinit self) -> IO[Result[Self.T, EffectFailure[Self.E]], Self.E]:
        """Materialize success or an ordinary failure; cancellation stays terminal."""
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
        return Self(program^)

    def _finalized(deinit self, var finalizer: _Finalizer[Self.E]) -> Self:
        var program = self^._into_program()
        program.frames.append(_Frame(_FINALIZE, _Erased(finalizer^), _no_invoke))
        return Self(program^)

    def guarantee(deinit self, var finalizer: IO[NoneType, Self.E]) -> Self:
        """Run the finalizer masked after every outcome, combining their errors."""
        return self^._finalized(_Finalizer[Self.E](False, Optional(finalizer^._into_program()), _Erased(), _no_cleanup[Self.E]))

    def on_cancel(deinit self, var finalizer: IO[NoneType, Self.E]) -> Self:
        """Run the finalizer masked only when the outcome observed cancellation."""
        return self^._finalized(_Finalizer[Self.E](True, Optional(finalizer^._into_program()), _Erased(), _no_cleanup[Self.E]))

    def guarantee_case[F: BorrowCallContract & Movable & Deinitable](deinit self, var factory: F) -> Self where F.Payload == ExitCase[Self.E] and F.Result == IO[NoneType, Self.E] and _OnceBorrowAvailable[F] and _ErrorCompatible[Self.E, F.Failure] and _Admitted[F]:
        """Build the finalizer from the borrowed exact exit case, then run it masked."""
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
        """Build and run a program masked; the Poll handle restores the outer state."""
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

        return Self(_Program[Self.E](_Head[Self.E](_MASK, _Erased(factory^), invoke)))

    @staticmethod
    def uncancelable(factory: def(var Poll[Self.E]) thin -> Self) -> Self:
        """Build and run a program masked with a native factory."""
        return Self.uncancelable(NativeUnary[Poll[Self.E], Self, Never, def(var Poll[Self.E]) thin -> Self, False](factory))

    def restore(deinit self, poll: Poll[Self.E]) -> Self:
        """Run this program under the cancellation state preceding poll's region."""
        return Self(_Program[Self.E](_Head[Self.E](_RESTORE, _Erased(_Restore[Self.E](poll.copy(), self^._into_program())))))

    @staticmethod
    def `async`[F: UnaryContract & Movable & Deinitable](var register: F, var withdrawal: IO[NoneType, Self.E]) -> Self where F.Arg == Completion[Self.T, Self.E] and _CallbackUnit[F.Out] and _Maps[Self.E, F]:
        """Register with an external source that completes this IO once.

        The withdrawal runs masked after every entered registration, then the
        IO settles with the completion and both outcomes' errors.
        """
        return Self._lifted(_Callback[F, IO[NoneType, Self.E]](register^, withdrawal^))

    @staticmethod
    def `async`(register: def(var Completion[Self.T, Self.E]) thin, var withdrawal: IO[NoneType, Self.E]) -> Self:
        """Register a native function with an external source."""
        return Self.`async`(NativeUnary[Completion[Self.T, Self.E], type_of(None), Never, def(var Completion[Self.T, Self.E]) thin, False](register), withdrawal^)

    @staticmethod
    def async_[F: UnaryContract & Movable & Deinitable](var register: F) -> Self where F.Arg == Completion[Self.T, Self.E] and _CallbackUnit[F.Out] and _Maps[Self.E, F]:
        """Register with an external source that needs no withdrawal."""
        var unit: NoneType = None
        return Self.`async`(register^, IO[NoneType, Self.E].pure(unit))

    @staticmethod
    def async_(register: def(var Completion[Self.T, Self.E]) thin) -> Self:
        """Register a native function that needs no withdrawal."""
        return Self.async_(NativeUnary[Completion[Self.T, Self.E], type_of(None), Never, def(var Completion[Self.T, Self.E]) thin, False](register))

    @staticmethod
    def eval_io[P: ReaderAction](var program: P) -> Self where IOContract[P].Compatible and P.Value == Self.T and IOContract[P].Error == Self.E:
        """Run a synchronous IO program inside this IO's context when reached."""
        return Self._lifted(_EvalIO(program^))

    @staticmethod
    def canceled() -> IO[NoneType, Self.E]:
        """Request cancellation of the running program; a mask defers its observation."""
        return IO[NoneType, Self.E]._lifted(_EvalIO(_cancel_request[Self.E]()))

    @staticmethod
    def cede() -> IO[NoneType, Self.E]:
        """Yield to other work once, then continue."""
        return IO[NoneType, Self.E]._lifted(_Cede[Self.E]())

    @staticmethod
    def never() -> Self:
        """Wait until canceled; never produces a value."""
        return Self._lifted(_Never[Self.T, Self.E]())

    @staticmethod
    def sleep(duration: Duration) -> IO[NoneType, Self.E]:
        """Wait cooperatively for a checked relative duration from entry; cancelable."""
        return IO[NoneType, Self.E]._lifted(_Sleep[Self.E](duration._nanoseconds))

    def both[U: Movable & Deinitable](deinit self, var other: IO[U, Self.E]) -> IO[Tuple[Self.T, U], Self.E]:
        """Run both cooperatively and drain both; errors keep left-before-right order."""
        return IO[Tuple[Self.T, U], Self.E]._lifted(_both(self^, other^))

    def race[U: Movable & Deinitable](deinit self, var other: IO[U, Self.E]) -> IO[RaceResult[Self.T, U], Self.E]:
        """Return the first outcome that is not cancellation-only, then cancel and drain the other."""
        return IO[RaceResult[Self.T, U], Self.E]._lifted(_race(self^, other^))

    def race_first[U: Movable & Deinitable](deinit self, var other: IO[U, Self.E]) -> IO[RaceResult[Self.T, U], Self.E]:
        """Return the first terminal outcome, then cancel and drain the other."""
        return IO[RaceResult[Self.T, U], Self.E]._lifted(_race_first(self^, other^))

    def timeout_to(deinit self, duration: Duration, var fallback: Self) -> Self:
        """After the timer wins, prefer this IO's drained result, else run the fallback."""
        return Self._lifted(_timeout_to(self^, duration._nanoseconds, fallback^))

    def timeout_after(deinit self, duration: Duration, var fallback: Self) -> Self:
        """Choose by first terminal outcome; drain this IO before running the fallback."""
        return Self._lifted(_timeout_after(self^, duration._nanoseconds, fallback^))

    def poll(mut self, context: IOContext[Self.E]) -> Step[Self.T, Self.E]:
        if not self._entered:
            var program = _Program[Self.E](_Head[Self.E]())
            swap(program, self._program)
            self._loop.unsafe_write(OwnedPointer(_RunLoop[Self.E](program^)))
            self._entered = True
        var step = self._loop.unsafe_assume_init()[].run(context)
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


@fieldwise_init
struct _Delay[F: ThunkContract & Movable & Deinitable, E: Movable & Deinitable](OnceThunk):
    """Evaluate a synchronous function into a pure IO."""
    var function: Self.F
    comptime Out = IO[Self.F.Out, Self.E]
    comptime Error = Self.F.Error

    def call_once(deinit self) raises Self.Error -> Self.Out:
        return Self.Out.pure(_thunk_once_as[Self.Error](self.function^))


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


struct Async[E: Movable & Deinitable](Monad, ErrorRecovery):
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
