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
from fp.callables.protocols import UnaryContract, ThunkContract
from fp.callables.invoke import _OnceUnaryAvailable, _OnceThunkAvailable
from fp.callables._receiver import _unary_once_as, _thunk_once_as
from fp._internal.erased import _Erased
from fp._internal.errors import _ErrorCompatible
from fp.data import Result, Ok, Err, NonEmptyList
from fp.effects import IOContext, Outcome, EffectFailure
from fp.effects.outcomes import _failure_as
from .kernel import Machine, Step, Wait, _Slot, _tick
from .erased import _ErasedMachine

# Head and frame kinds.
comptime _EMPTY = 0
comptime _PURE = 1
comptime _FAIL = 2
comptime _LEAF = 3
comptime _DEFER = 4
comptime _BIND = 5
comptime _RECOVER = 6

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


struct _RunLoop[E: Movable & Deinitable](Movable):
    """Evaluate heads and deliver outcomes through one explicit frame stack."""
    var state: Int
    var head: _Head[Self.E]
    var value: _Erased
    var failure: Optional[EffectFailure[Self.E]]
    var frames: List[_Frame]
    var leaf: Optional[_Slot[_Leaf[Self.E], _Erased, Self.E]]
    var protected: Bool

    def __init__(out self, var program: _Program[Self.E]):
        self.state = _EVALUATE
        self.head = _Head[Self.E]()
        self.value = _Erased()
        self.failure = None
        self.frames = List[_Frame]()
        self.leaf = None
        self.protected = False
        program^.install_into(self)

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
        for _ in range(_BUDGET):
            if self.state == _EVALUATE:
                self.evaluate(context)
            elif self.state == _VALUE:
                if not len(self.frames):
                    var success: Outcome[_Erased, Self.E] = Optional(Result[_Erased, EffectFailure[Self.E]](Ok(self.take_value())))
                    return Step[_Erased, Self.E]._make(Optional(success^), Wait(), self.protected)
                var frame = self.frames.pop()
                if frame.kind == _BIND:
                    if context.canceled():
                        # The handoff checkpoint drops the unopened continuation.
                        _ = self.take_value()
                        self.state = _CANCELED
                        continue
                    self.protected = False
                    frame^.call(self.address())
            elif self.state == _FAILURE:
                if not len(self.frames):
                    var failed: Outcome[_Erased, Self.E] = Optional(Result[_Erased, EffectFailure[Self.E]](Err(self.failure.take())))
                    return Step[_Erased, Self.E]._make(Optional(failed^), Wait(), self.protected)
                var frame = self.frames.pop()
                if frame.kind == _RECOVER and not self.failure.value().canceled:
                    if context.canceled():
                        self.failure.value().canceled = True
                        continue
                    self.protected = False
                    frame^.call(self.address())
            elif self.state == _CANCELED:
                if not len(self.frames):
                    var canceled: Outcome[_Erased, Self.E] = None
                    return Step[_Erased, Self.E]._make(Optional(canceled^), Wait(), self.protected)
                _ = self.frames.pop()
            else:
                _ = _tick(self.leaf.value(), context)
                if not self.leaf.value().done():
                    return Step[_Erased, Self.E].pending(self.leaf.value().waiting())
                self.finish_leaf()
        return Step[_Erased, Self.E].pending(Wait())

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
        else:
            self.leaf = Optional(_Slot[_Leaf[Self.E], _Erased, Self.E](self.head.take_box().take[_Leaf[Self.E]]()))
            self.state = _WAITING

    def finish_leaf(mut self):
        var step = self.leaf.value().take_step()
        self.leaf = None
        self.protected = step._protected_success
        var outcome = step^._outcome()
        if not outcome:
            self.state = _CANCELED
        elif outcome.value().is_ok():
            self.set_value(outcome.take()._take_ok())
        else:
            self.set_failure(outcome.take()._take_err())


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
