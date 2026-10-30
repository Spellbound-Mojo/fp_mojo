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
from std.memory import OwnedPointer, MaybeUninit
from std.os import abort
from fp.callables.protocols import UnaryContract, ThunkContract, BorrowCallContract
from fp.callables.invoke import _OnceUnaryAvailable, _OnceThunkAvailable, _OnceBorrowAvailable
from fp.callables._receiver import _unary_once_as, _thunk_once_as, _borrow_once_as
from fp._internal.erased import _Erased
from fp._internal.errors import _ErrorCompatible
from fp.data import Result, Ok, Err, NonEmptyList
from fp.effects import IOContext, Outcome, EffectFailure, ExitCase
from fp.effects.outcomes import _failure_as, _finish, _ExitState
from fp.effects._io_core import _settle
from fp.effects.finalization import Poll as _SyncPoll
from .kernel import Machine, Step, Wait, _Slot, _tick
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


struct IO[T: Movable & Deinitable, E: Movable & Deinitable](Machine):
    """An asynchronous effect producing T or failing with E, run by the private engine.

    An IO runs once. Unopened values may be dropped; disposal is iterative.
    """
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

    @staticmethod
    def lift[P: Machine](var machine: P) -> Self where P.Value == Self.T and P.Error == Self.E:
        return Self(_Program[Self.E](_Head[Self.E](_LEAF, _Erased(_Leaf[Self.E](_Boxed[P, Self.E](machine^))))))

    @staticmethod
    def defer[F: ThunkContract & Movable & Deinitable](var factory: F) -> Self where _OnceThunkAvailable[F] and _ErrorCompatible[Self.E, F.Error] and F.Out == Self:
        def invoke(var callable: _Erased, loop: MutOpaquePointer[_]):
            comptime assert _OnceThunkAvailable[F] and _ErrorCompatible[Self.E, F.Error] and F.Out == Self
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

        return Self(_Program[Self.E](_Head[Self.E](_DEFER, _Erased(factory^), invoke)))

    def flat_map[F: UnaryContract & Movable & Deinitable](deinit self, var f: F) -> IO[downcast[F.Out, Machine].Value, Self.E] where F.Arg == Self.T and _OnceUnaryAvailable[F] and _ErrorCompatible[Self.E, F.Error] and F.Out == IO[downcast[F.Out, Machine].Value, Self.E]:
        comptime U = downcast[F.Out, Machine].Value

        def invoke(var callable: _Erased, loop: MutOpaquePointer[_]):
            comptime assert F.Arg == Self.T and _OnceUnaryAvailable[F] and _ErrorCompatible[Self.E, F.Error] and F.Out == IO[U, Self.E]
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

        var program = self^._into_program()
        program.frames.append(_Frame(_BIND, _Erased(f^), invoke))
        return IO[U, Self.E](program^)

    def map[F: UnaryContract & Movable & Deinitable](deinit self, var f: F) -> IO[F.Out, Self.E] where F.Arg == Self.T and _OnceUnaryAvailable[F] and _ErrorCompatible[Self.E, F.Error]:
        def invoke(var callable: _Erased, loop: MutOpaquePointer[_]):
            comptime assert F.Arg == Self.T and _OnceUnaryAvailable[F] and _ErrorCompatible[Self.E, F.Error]
            ref run = _loop_at[Self.E](loop)
            var argument = run.take_value().take[Self.T]()
            comptime if F.Error == Never:
                run.set_value(_Erased(_unary_once_as[Never](callable^.take[F](), rebind_var[F.Arg](argument^))))
            else:
                try:
                    run.set_value(_Erased(_unary_once_as[Self.E](callable^.take[F](), rebind_var[F.Arg](argument^))))
                except error:
                    run.set_failure(EffectFailure[Self.E](NonEmptyList(error^), False))

        var program = self^._into_program()
        program.frames.append(_Frame(_BIND, _Erased(f^), invoke))
        return IO[F.Out, Self.E](program^)

    def handle_error_with[H: UnaryContract & Movable & Deinitable](deinit self, var handler: H) -> Self where H.Arg == EffectFailure[Self.E] and _OnceUnaryAvailable[H] and _ErrorCompatible[Self.E, H.Error] and H.Out == Self:
        def invoke(var callable: _Erased, loop: MutOpaquePointer[_]):
            comptime assert H.Arg == EffectFailure[Self.E] and _OnceUnaryAvailable[H] and _ErrorCompatible[Self.E, H.Error] and H.Out == Self
            ref run = _loop_at[Self.E](loop)
            var failure = run.failure.take()
            comptime if H.Error == Never:
                rebind_var[Self](_unary_once_as[Never](callable^.take[H](), rebind_var[H.Arg](failure^)))._into_program().install_into(run)
            else:
                try:
                    rebind_var[Self](_unary_once_as[Self.E](callable^.take[H](), rebind_var[H.Arg](failure^)))._into_program().install_into(run)
                except error:
                    run.set_failure(EffectFailure[Self.E](NonEmptyList(error^), False))

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

    def guarantee_case[F: BorrowCallContract & Movable & Deinitable](deinit self, var factory: F) -> Self where F.Payload == ExitCase[Self.E] and F.Result == IO[NoneType, Self.E] and _OnceBorrowAvailable[F] and _ErrorCompatible[Self.E, F.Failure]:
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
    def uncancelable[F: UnaryContract & Movable & Deinitable](var factory: F) -> Self where F.Arg == Poll[Self.E] and F.Out == Self and _OnceUnaryAvailable[F] and _ErrorCompatible[Self.E, F.Error]:
        """Build and run a program masked; the Poll handle restores the outer state."""
        def invoke(var callable: _Erased, loop: MutOpaquePointer[_]):
            comptime assert F.Arg == Poll[Self.E] and F.Out == Self and _OnceUnaryAvailable[F] and _ErrorCompatible[Self.E, F.Error]
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

    def restore(deinit self, poll: Poll[Self.E]) -> Self:
        """Run this program under the cancellation state preceding poll's region."""
        return Self(_Program[Self.E](_Head[Self.E](_RESTORE, _Erased(_Restore[Self.E](poll.copy(), self^._into_program())))))

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
