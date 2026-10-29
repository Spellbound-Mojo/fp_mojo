"""Owned sequencing and fixed-type iteration over the shared execution slots."""
from std.builtin.rebind import downcast, rebind_var
from std.os import abort
from std.utils import Variant
from fp.callables.protocols import UnaryContract, OnceThunk
from fp.callables.invoke import call_repeated, RepeatableUnary, _OnceUnaryAvailable
from fp.callables._binding import _OwnedUnary
from fp._internal.errors import _ErrorCompatible
from fp.adt.data import _ChoiceType
from fp.data.control import _ControlShape
from fp.data import Result, Ok, ControlFlow, Continue, Break, Left, Right
from fp.effects import IOContext, Outcome, EffectFailure
from fp.effects.outcomes import _capture, _failure_as
from .kernel import Machine, Step, Wait, _Slot, _tick


@fieldwise_init
struct Pure[T: Movable & Deinitable, E: Movable & Deinitable](Machine):
    var value: Optional[Self.T]
    comptime Value = Self.T
    comptime Error = Self.E

    def poll(mut self, context: IOContext[Self.E]) -> Step[Self.T, Self.E]:
        if context.canceled():
            return .ready(None)
        return .ready(Optional(Result[Self.T, EffectFailure[Self.E]](Ok(self.value.take()))))


def pure[E: Movable & Deinitable, T: Movable & Deinitable](var value: T) -> Pure[T, E]:
    return Pure[T, E](Optional(value^))


struct Bind[P: Machine, F: UnaryContract & Movable & Deinitable](Machine):
    comptime Next = downcast[Self.F.Out, Machine]
    comptime Value = Self.Next.Value
    comptime Error = Self.P.Error
    var source: _Slot[Self.P, Self.P.Value, Self.P.Error]
    var factory: Optional[Self.F]
    var value: Optional[Self.P.Value]
    var next: Optional[_Slot[Self.Next, Self.Next.Value, Self.Next.Error]]
    var phase: Int

    def __init__(out self, var program: Self.P, var next: Self.F):
        comptime assert Self.F.Arg == Self.P.Value and _OnceUnaryAvailable[Self.F]
        comptime assert Self.Next.Error == Self.Error and _ErrorCompatible[Self.Error, Self.F.Error]
        self.source = _Slot[Self.P, Self.P.Value, Self.P.Error](program^)
        self.factory = Optional(next^)
        self.value = None
        self.next = None
        self.phase = 0

    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        comptime assert Self.F.Arg == Self.P.Value and _OnceUnaryAvailable[Self.F]
        comptime assert Self.Next.Error == Self.Error and _ErrorCompatible[Self.Error, Self.F.Error]
        match self.phase:
            case 0:
                _ = _tick(self.source, context)
                if not self.source.done():
                    return .pending(self.source.waiting())
                var outcome = self.source.take_outcome()
                if not outcome or outcome.value().is_err():
                    self.phase = 3
                    return .ready(_failure_as[Self.Value](outcome^))
                self.value = Optional(outcome.take()._take_ok())
                self.phase = 1
                return .pending(Wait())
            case 1:
                if context.canceled():
                    self.phase = 3
                    return .ready(None)
                var built = _capture[Self.Error](_OwnedUnary(self.factory.take(), rebind_var[Self.F.Arg](self.value.take())))
                if built.is_err():
                    self.phase = 3
                    return .ready(_failure_as[Self.Value](Optional(built^)))
                self.next = Optional(_Slot[Self.Next, Self.Next.Value, Self.Next.Error](rebind_var[Self.Next](built^._take_ok())))
                self.phase = 2
                return .pending(Wait())
            case 2:
                _ = _tick(self.next.value(), rebind[IOContext[Self.Next.Error]](context))
                if not self.next.value().done():
                    return .pending(self.next.value().waiting())
                self.phase = 3
                return rebind_var[Step[Self.Value, Self.Error]](self.next.value().take_step())
            case _:
                abort("bind polled after completion")


def bind[P: Machine, F: UnaryContract & Movable & Deinitable](var program: P, var next: F) -> Bind[P, F]:
    return Bind(program^, next^)


@fieldwise_init
struct _RepeatFactory[F: UnaryContract & Movable & Deinitable, o: MutOrigin](OnceThunk):
    # The native mutable receiver is borrowed only for the capture call.
    var factory: Pointer[Self.F, Self.o]
    var value: Self.F.Arg
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error

    def call_once(deinit self) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F]
        return call_repeated(self.factory[], self.value^)


trait _LoopPolicy:
    """Interpret one completed step without changing the shared loop lifecycle."""
    comptime Factory: UnaryContract & Movable & Deinitable
    comptime Compatible: Bool = True
    comptime Item: Movable & Deinitable
    comptime Value: Movable & Deinitable
    @staticmethod
    def done(factory: Self.Factory, item: Self.Item) -> Bool:
        ...
    @staticmethod
    def result(var item: Self.Item) -> Self.Value:
        ...
    @staticmethod
    def next(var item: Self.Item) -> Self.Factory.Arg:
        ...


struct _ControlLoop[F: UnaryContract & Movable & Deinitable](_LoopPolicy):
    comptime Factory = Self.F
    comptime Item = downcast[Self.F.Out, Machine].Value
    comptime Shape = downcast[downcast[Self.Item, _ChoiceType].Of, _ControlShape]
    comptime Value = Self.Shape.BreakValue
    comptime Compatible = Self.Item == ControlFlow[Self.Value, Self.F.Arg]
    @staticmethod
    def done(factory: Self.F, item: Self.Item) -> Bool:
        comptime assert Self.Item == ControlFlow[Self.Value, Self.F.Arg]
        return rebind[ControlFlow[Self.Value, Self.F.Arg]](item).isa[Break[Self.Value]]()
    @staticmethod
    def result(var item: Self.Item) -> Self.Value:
        comptime assert Self.Item == ControlFlow[Self.Value, Self.F.Arg]
        return rebind_var[ControlFlow[Self.Value, Self.F.Arg]](item^).unwrap[Break[Self.Value]]().into_payload()
    @staticmethod
    def next(var item: Self.Item) -> Self.F.Arg:
        comptime assert Self.Item == ControlFlow[Self.Value, Self.F.Arg]
        return rebind_var[ControlFlow[Self.Value, Self.F.Arg]](item^).unwrap[Continue[Self.F.Arg]]().into_payload()


struct Loop[F: UnaryContract & Movable & Deinitable, C: _LoopPolicy = _ControlLoop[F]](Machine):
    comptime Next = downcast[Self.F.Out, Machine]
    comptime Value = Self.C.Value
    comptime Error = Self.Next.Error
    var factory: Self.F
    var state: Optional[Self.F.Arg]
    var active: Optional[_Slot[Self.Next, Self.Next.Value, Self.Next.Error]]
    var completed: Bool

    def __init__(out self, var initial: Self.F.Arg, var step: Self.F):
        comptime assert RepeatableUnary[Self.F], "loop requires a repeatable factory"
        comptime assert Self.C.Factory == Self.F and Self.C.Item == Self.Next.Value, "loop policy must match its factory and result"
        comptime assert Self.C.Compatible, "loop state must match Continue payload"
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error]
        self.factory = step^
        self.state = Optional(initial^)
        self.active = None
        self.completed = False

    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        comptime assert RepeatableUnary[Self.F]
        comptime assert Self.C.Factory == Self.F and Self.C.Item == Self.Next.Value
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error]
        if self.completed:
            abort("loop polled after completion")
        if not self.active:
            if context.canceled():
                self.completed = True
                return .ready(None)
            var built = _capture[Self.Error](_RepeatFactory(Pointer(to=self.factory), self.state.take()))
            if built.is_err():
                self.completed = True
                return .ready(_failure_as[Self.Value](Optional(built^)))
            self.active = Optional(_Slot[Self.Next, Self.Next.Value, Self.Next.Error](rebind_var[Self.Next](built^._take_ok())))
            return .pending(Wait())
        _ = _tick(self.active.value(), context)
        if not self.active.value().done():
            return .pending(self.active.value().waiting())
        var outcome = self.active.value().take_outcome()
        self.active = None
        if not outcome or outcome.value().is_err():
            self.completed = True
            return .ready(_failure_as[Self.Value](outcome^))
        var item = rebind_var[Self.C.Item](outcome.take()._take_ok())
        if Self.C.done(rebind[Self.C.Factory](self.factory), item):
            self.completed = True
            return .ready(Optional(Result[Self.Value, EffectFailure[Self.Error]](Ok(Self.C.result(item^)))))
        self.state = Optional(rebind_var[Self.F.Arg](Self.C.next(item^)))
        return .pending(Wait())


def loop[S: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var initial: S, var step: F) -> Loop[F] where S == F.Arg:
    return Loop(rebind_var[F.Arg](initial^), step^)


@fieldwise_init
struct _Selected[P: Machine, Q: Machine](Machine):
    var branch: Variant[Left[Self.P], Right[Self.Q]]
    comptime Value = Self.P.Value
    comptime Error = Self.P.Error
    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        comptime assert Self.P.Value == Self.Q.Value and Self.P.Error == Self.Q.Error
        if self.branch.isa[Left[Self.P]]():
            return self.branch[Left[Self.P]].value.poll(context)
        return rebind_var[Step[Self.Value, Self.Error]](self.branch[Right[Self.Q]].value.poll(rebind[IOContext[Self.Q.Error]](context)))
