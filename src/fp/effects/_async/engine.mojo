"""The private IO run loop: erased nodes evaluated iteratively over canonical owners.

An IO owns a node tree until it is entered, then a run loop with an explicit
frame stack. Binds, recoveries and deferred construction are interpreter nodes
and never recurse natively; typed machines run as leaves through the canonical
slot. Values cross nodes in construction-paired erased boxes, and failures keep
their exact error type because one IO chain shares it.
"""
from std.builtin.rebind import downcast, rebind_var
from std.memory import OwnedPointer
from std.os import abort
from fp.callables.protocols import UnaryContract, ThunkContract
from fp.callables.invoke import _OnceUnaryAvailable, _OnceThunkAvailable
from fp.callables._binding import _OwnedUnary, _OwnedThunk
from fp._internal.erased import _Erased
from fp._internal.errors import _ErrorCompatible
from fp.data import Result, Ok, Err, NonEmptyList
from fp.effects import IOContext, Outcome, EffectFailure
from fp.effects.outcomes import _capture, _failure_as
from .kernel import Machine, Step, Wait, _Slot, _tick
from .erased import _ErasedMachine

comptime _PURE = 0
comptime _FAIL = 1
comptime _LEAF = 2
comptime _DEFER = 3
comptime _BIND = 4
comptime _RECOVER = 5

# Interpreter transitions per poll before yielding; Pass 8b makes this a policy.
comptime _BUDGET = 1024

comptime _Leaf[E: Movable & Deinitable] = _ErasedMachine[_Erased, E]


@fieldwise_init
struct _Input[E: Movable & Deinitable](Movable):
    """What a frame hands its callback: a boxed value, a failure, or nothing."""
    var value: Optional[_Erased]
    var failure: Optional[EffectFailure[Self.E]]


# Mojo 1.2 crashes compiling a stored function type whose result contains the
# function's owner (_Call -> _Node -> _Call). A callback therefore writes its
# node into the run loop's lent slot instead of returning it.
comptime _Invoke[E: Movable & Deinitable] = def(var _Erased, var _Input[E], MutOpaquePointer[_]) thin


struct _Call[E: Movable & Deinitable](Movable):
    """One erased callback, invoked at most once by a function specialized at construction."""
    var _callable: _Erased
    var _invoke: _Invoke[Self.E]

    def __init__(out self, var callable: _Erased, invoke: _Invoke[Self.E]):
        self._callable = callable^
        self._invoke = invoke

    def call(deinit self, var input: _Input[Self.E], target: MutOpaquePointer[_]):
        self._invoke(self._callable^, input^, target)


def _install[E: Movable & Deinitable](target: MutOpaquePointer[_], var node: _Node[E]):
    # The run loop lends its own Optional[_Node[E]] slot; the engine fixes that type.
    target.unsafe_bitcast[Optional[_Node[E]]]()[] = Optional(node^)


struct _Node[E: Movable & Deinitable](Movable):
    """One unevaluated step; sources link through owned indirection."""
    var kind: Int
    var value: Optional[_Erased]
    var failure: Optional[EffectFailure[Self.E]]
    var leaf: Optional[_Leaf[Self.E]]
    var call: Optional[_Call[Self.E]]
    var source: Optional[OwnedPointer[_Node[Self.E]]]

    def __init__(out self, kind: Int):
        self.kind = kind
        self.value = None
        self.failure = None
        self.leaf = None
        self.call = None
        self.source = None

    def __deinit__(deinit self):
        # Detach descendants before each node drops, so destruction never recurses.
        var pending = List[OwnedPointer[_Node[Self.E]]]()
        var source = self.source^
        if source:
            pending.append(source.take())
        while len(pending):
            var node = pending.pop()
            if node[].source:
                pending.append(node[].source.take())

    @staticmethod
    def pure(var value: _Erased) -> Self:
        var node = Self(_PURE)
        node.value = Optional(value^)
        return node^

    @staticmethod
    def fail(var failure: EffectFailure[Self.E]) -> Self:
        var node = Self(_FAIL)
        node.failure = Optional(failure^)
        return node^

    @staticmethod
    def lift(var machine: _Leaf[Self.E]) -> Self:
        var node = Self(_LEAF)
        node.leaf = Optional(machine^)
        return node^

    @staticmethod
    def deferred(var call: _Call[Self.E]) -> Self:
        var node = Self(_DEFER)
        node.call = Optional(call^)
        return node^

    @staticmethod
    def chain(kind: Int, var source: Self, var call: _Call[Self.E]) -> Self:
        var node = Self(kind)
        node.call = Optional(call^)
        node.source = Optional(OwnedPointer(source^))
        return node^


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


@fieldwise_init
struct _Frame[E: Movable & Deinitable](Movable):
    var kind: Int
    var call: _Call[Self.E]

    def take_call(deinit self) -> _Call[Self.E]:
        return self.call^


struct _RunLoop[E: Movable & Deinitable](Movable):
    """Evaluate nodes and deliver outcomes through an explicit frame stack."""
    var current: Optional[_Node[Self.E]]
    # Present while an outcome awaits delivery; the inner value may be cancellation.
    var outcome: Optional[Outcome[_Erased, Self.E]]
    var protected: Bool
    var frames: List[_Frame[Self.E]]
    var leaf: Optional[_Slot[_Leaf[Self.E], _Erased, Self.E]]

    def __init__(out self, var root: _Node[Self.E]):
        self.current = Optional(root^)
        self.outcome = None
        self.protected = False
        self.frames = List[_Frame[Self.E]]()
        self.leaf = None

    def run(mut self, context: IOContext[Self.E]) -> Step[_Erased, Self.E]:
        for _ in range(_BUDGET):
            if self.leaf:
                _ = _tick(self.leaf.value(), context)
                if not self.leaf.value().done():
                    return Step[_Erased, Self.E].pending(self.leaf.value().waiting())
                var step = self.leaf.value().take_step()
                self.leaf = None
                self.protected = step._protected_success
                self.outcome = Optional(step^._outcome())
            elif self.outcome:
                if not len(self.frames):
                    return Step[_Erased, Self.E]._make(Optional(self.outcome.take()), Wait(), self.protected)
                self.deliver(context)
            else:
                self.evaluate(context)
        return Step[_Erased, Self.E].pending(Wait())

    def slot(mut self) -> MutOpaquePointer[origin_of(self.current)]:
        return Pointer(to=self.current).unsafe_bitcast[NoneType]()

    def deliver(mut self, context: IOContext[Self.E]):
        var outcome = self.outcome.take()
        var frame = self.frames.pop()
        if frame.kind == _BIND:
            if not outcome or outcome.value().is_err():
                self.outcome = Optional(outcome^)
                return
            if context.canceled():
                # The handoff checkpoint drops the unopened continuation.
                var canceled: Outcome[_Erased, Self.E] = None
                self.outcome = Optional(canceled^)
                return
            var value = outcome.take()._take_ok()
            self.protected = False
            frame^.take_call().call(_Input[Self.E](Optional(value^), None), self.slot())
            return
        if not outcome or outcome.value().is_ok() or outcome.value()._err().value.canceled:
            self.outcome = Optional(outcome^)
            return
        var failure = outcome.take()._take_err()
        if context.canceled():
            failure.canceled = True
            var failed: Outcome[_Erased, Self.E] = Optional(Result[_Erased, EffectFailure[Self.E]](Err(failure^)))
            self.outcome = Optional(failed^)
            return
        self.protected = False
        frame^.take_call().call(_Input[Self.E](None, Optional(failure^)), self.slot())

    def evaluate(mut self, context: IOContext[Self.E]):
        var node = self.current.take()
        if node.kind == _PURE:
            self.protected = False
            var success: Outcome[_Erased, Self.E] = Optional(Result[_Erased, EffectFailure[Self.E]](Ok(node.value.take())))
            self.outcome = Optional(success^)
        elif node.kind == _FAIL:
            self.protected = False
            var failed: Outcome[_Erased, Self.E] = Optional(Result[_Erased, EffectFailure[Self.E]](Err(node.failure.take())))
            self.outcome = Optional(failed^)
        elif node.kind == _LEAF:
            self.leaf = Optional(_Slot[_Leaf[Self.E], _Erased, Self.E](node.leaf.take()))
        elif node.kind == _DEFER:
            if context.canceled():
                var canceled: Outcome[_Erased, Self.E] = None
                self.outcome = Optional(canceled^)
                return
            node.call.take().call(_Input[Self.E](None, None), self.slot())
        else:
            self.frames.append(_Frame[Self.E](node.kind, node.call.take()))
            self.current = Optional(node.source.take().into_inner())


struct IO[T: Movable & Deinitable, E: Movable & Deinitable](Machine):
    """An asynchronous effect producing T or failing with E, run by the private engine.

    An IO runs once. Unopened values may be dropped; disposal is iterative.
    """
    comptime Value = Self.T
    comptime Error = Self.E
    var _root: Optional[_Node[Self.E]]
    var _loop: Optional[_RunLoop[Self.E]]

    def __init__(out self, var root: _Node[Self.E]):
        self._root = Optional(root^)
        self._loop = None

    def _into_node(deinit self) -> _Node[Self.E]:
        if not self._root:
            abort("an entered IO cannot be composed")
        return self._root.take()

    @staticmethod
    def pure(var value: Self.T) -> Self:
        return Self(_Node[Self.E].pure(_Erased(value^)))

    @staticmethod
    def raise_error(var error: Self.E) -> Self:
        return Self(_Node[Self.E].fail(EffectFailure[Self.E](NonEmptyList(error^), False)))

    @staticmethod
    def lift[P: Machine](var machine: P) -> Self where P.Value == Self.T and P.Error == Self.E:
        return Self(_Node[Self.E].lift(_Leaf[Self.E](_Boxed[P, Self.E](machine^))))

    @staticmethod
    def defer[F: ThunkContract & Movable & Deinitable](var factory: F) -> Self where _OnceThunkAvailable[F] and _ErrorCompatible[Self.E, F.Error] and F.Out == Self:
        def invoke(var callable: _Erased, var input: _Input[Self.E], target: MutOpaquePointer[_]):
            comptime assert _OnceThunkAvailable[F] and _ErrorCompatible[Self.E, F.Error] and F.Out == Self
            var built = _capture[Self.E](_OwnedThunk(callable^.take[F]()))
            if built.is_err():
                _install(target, _Node[Self.E].fail(built^._take_err()))
                return
            _install(target, rebind_var[Self](built^._take_ok())._into_node())

        return Self(_Node[Self.E].deferred(_Call[Self.E](_Erased(factory^), invoke)))

    def flat_map[F: UnaryContract & Movable & Deinitable](deinit self, var f: F) -> IO[downcast[F.Out, Machine].Value, Self.E] where F.Arg == Self.T and _OnceUnaryAvailable[F] and _ErrorCompatible[Self.E, F.Error] and F.Out == IO[downcast[F.Out, Machine].Value, Self.E]:
        comptime U = downcast[F.Out, Machine].Value

        def invoke(var callable: _Erased, var input: _Input[Self.E], target: MutOpaquePointer[_]):
            comptime assert F.Arg == Self.T and _OnceUnaryAvailable[F] and _ErrorCompatible[Self.E, F.Error] and F.Out == IO[U, Self.E]
            var argument = input.value.take().take[Self.T]()
            var built = _capture[Self.E](_OwnedUnary(callable^.take[F](), rebind_var[F.Arg](argument^)))
            if built.is_err():
                _install(target, _Node[Self.E].fail(built^._take_err()))
                return
            _install(target, rebind_var[IO[U, Self.E]](built^._take_ok())._into_node())

        return IO[U, Self.E](_Node[Self.E].chain(_BIND, self^._into_node(), _Call[Self.E](_Erased(f^), invoke)))

    def map[F: UnaryContract & Movable & Deinitable](deinit self, var f: F) -> IO[F.Out, Self.E] where F.Arg == Self.T and _OnceUnaryAvailable[F] and _ErrorCompatible[Self.E, F.Error]:
        def invoke(var callable: _Erased, var input: _Input[Self.E], target: MutOpaquePointer[_]):
            comptime assert F.Arg == Self.T and _OnceUnaryAvailable[F] and _ErrorCompatible[Self.E, F.Error]
            var argument = input.value.take().take[Self.T]()
            var built = _capture[Self.E](_OwnedUnary(callable^.take[F](), rebind_var[F.Arg](argument^)))
            if built.is_err():
                _install(target, _Node[Self.E].fail(built^._take_err()))
                return
            _install(target, _Node[Self.E].pure(_Erased(built^._take_ok())))

        return IO[F.Out, Self.E](_Node[Self.E].chain(_BIND, self^._into_node(), _Call[Self.E](_Erased(f^), invoke)))

    def handle_error_with[H: UnaryContract & Movable & Deinitable](deinit self, var handler: H) -> Self where H.Arg == EffectFailure[Self.E] and _OnceUnaryAvailable[H] and _ErrorCompatible[Self.E, H.Error] and H.Out == Self:
        def invoke(var callable: _Erased, var input: _Input[Self.E], target: MutOpaquePointer[_]):
            comptime assert H.Arg == EffectFailure[Self.E] and _OnceUnaryAvailable[H] and _ErrorCompatible[Self.E, H.Error] and H.Out == Self
            var failure = input.failure.take()
            var built = _capture[Self.E](_OwnedUnary(callable^.take[H](), rebind_var[H.Arg](failure^)))
            if built.is_err():
                _install(target, _Node[Self.E].fail(built^._take_err()))
                return
            _install(target, rebind_var[Self](built^._take_ok())._into_node())

        return Self(_Node[Self.E].chain(_RECOVER, self^._into_node(), _Call[Self.E](_Erased(handler^), invoke)))

    def poll(mut self, context: IOContext[Self.E]) -> Step[Self.T, Self.E]:
        if not self._loop:
            self._loop = Optional(_RunLoop[Self.E](self._root.take()))
        var step = self._loop.value().run(context)
        if not step._completed:
            return Step[Self.T, Self.E].pending(step^._waiting())
        var protected = step._protected_success
        var outcome = step^._outcome()
        if outcome and outcome.value().is_ok():
            # The run loop's final value was boxed by a node this IO's type fixed as T.
            var success: Outcome[Self.T, Self.E] = Optional(Result[Self.T, EffectFailure[Self.E]](Ok(outcome.take()._take_ok().take[Self.T]())))
            return Step[Self.T, Self.E]._make(Optional(success^), Wait(), protected)
        var failed = _failure_as[Self.T](outcome^)
        return Step[Self.T, Self.E]._make(Optional(failed^), Wait(), protected)
