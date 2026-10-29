"""Structured first-terminal races and timeouts with complete loser draining."""
from std.builtin.rebind import rebind_var
from std.utils import Variant
from fp.adt.data import Cases, Choice, Data, Value
from fp.data import Left, Right, Result, Ok, Err
from fp.effects import IOContext, Outcome, EffectFailure
from fp.effects.outcomes import _finish, _failure_as
from fp.callables import OnceUnary
from .kernel import Machine, Step, Wait, Sleep, _Slot, _tick
from .children import _Pair
from .composition import Bind, Pure, pure, bind, _Selected


struct _RaceCases[A: Movable & Deinitable, B: Movable & Deinitable](Data):
    comptime Layer[R: Value] = Cases[Left[Self.A], Right[Self.B]]


comptime RaceResult[A: Movable & Deinitable, B: Movable & Deinitable] = Choice[_RaceCases[A, B]]


def _winner[A: Movable & Deinitable, B: Movable & Deinitable, E: Movable & Deinitable, left: Bool](var outcome: Outcome[A if left else B, E]) -> Outcome[RaceResult[A, B], E]:
    if not outcome or outcome.value().is_err():
        return _failure_as[RaceResult[A, B]](outcome^)
    var selected: RaceResult[A, B]
    comptime if left:
        selected = RaceResult[A, B](Left(outcome.take()._take_ok()))
    else:
        selected = RaceResult[A, B](Right(outcome.take()._take_ok()))
    return Optional(Result[RaceResult[A, B], EffectFailure[E]](Ok(selected^)))


def _loser[T: Movable & Deinitable, E: Movable & Deinitable](var outcome: Outcome[T, E]) -> Outcome[NoneType, E]:
    # Losing cancellation is expected, but errors remain observable. Parent
    # cancellation is independently settled by the enclosing execution slot.
    if outcome and outcome.value().is_err():
        var failure = outcome.take()._take_err()
        failure.canceled = False
        return Optional(Result[NoneType, EffectFailure[E]](Err(failure^)))
    var unit: NoneType = None
    return Optional(Result[NoneType, EffectFailure[E]](Ok(unit)))


struct Race[P: Machine, Q: Machine, policy: Int = 0](Machine):
    comptime Value = RaceResult[Self.P.Value, Self.Q.Value]
    comptime Error = Self.P.Error
    var pair: _Pair[Self.P, Self.Q, Self.P.Value, Self.Q.Value, Self.Error]
    var winner: Optional[Int]

    def __init__(out self, var left: Self.P, var right: Self.Q):
        comptime assert Self.P.Error == Self.Q.Error, "race requires the same exact error type"
        comptime assert 0 <= Self.policy <= 2, "unknown race selection policy"
        self.pair = _Pair[Self.P, Self.Q, Self.P.Value, Self.Q.Value, Self.Error](left^, right^)
        self.winner = None

    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        comptime assert Self.P.Error == Self.Q.Error
        match self.pair.select(context, False):
            case 0:
                _ = _tick(self.pair.left.slot, self.pair.left.context)
            case 1:
                _ = _tick(rebind[_Slot[Self.Q, Self.Q.Value, Self.Q.Error]](self.pair.right.slot), rebind[IOContext[Self.Q.Error]](self.pair.right.context))
            case _:
                pass
        if not self.winner:
            if self.pair.left.slot.done():
                self.winner = Optional(0)
            elif self.pair.right.slot.done():
                self.winner = Optional(1)
            if self.winner:
                self.pair.request_stop(context, True)
        if self.pair.left.slot.done() and self.pair.right.slot.done():
            self.pair.completed = True
            var left = self.pair.left.slot.take_outcome()
            var right = self.pair.right.slot.take_outcome()
            var selected = self.winner.value()
            comptime if Self.policy == 1:
                if selected == 0 and not left:
                    selected = 1
                elif selected == 1 and not right:
                    selected = 0
            elif Self.policy == 2:
                if selected == 1 and left:
                    selected = 0
            if selected == 0:
                return .ready(_finish(_winner[Self.P.Value, Self.Q.Value, Self.Error, True](left^), _loser(right^)))
            return .ready(_finish(_winner[Self.P.Value, Self.Q.Value, Self.Error, False](right^), _loser(left^)))
        return .pending(self.pair.waiting())


def race_first[P: Machine, Q: Machine](var left: P, var right: Q) -> Race[P, Q]:
    return Race(left^, right^)


def race[P: Machine, Q: Machine](var left: P, var right: Q) -> Race[P, Q, 1]:
    return Race[P, Q, 1](left^, right^)


@fieldwise_init
struct _TimeoutBranch[T: Movable & Deinitable, Q: Machine](OnceUnary):
    var fallback: Self.Q
    comptime Arg = RaceResult[Self.T, NoneType]
    comptime Out = _Selected[Pure[Self.T, Self.Q.Error], Self.Q]
    def call_once(deinit self, var selected: Self.Arg) -> Self.Out:
        comptime assert Self.T == Self.Q.Value
        comptime Branch = Variant[Left[Pure[Self.T, Self.Q.Error]], Right[Self.Q]]
        if selected.isa[Left[Self.T]]():
            return Self.Out(Branch(Left(pure[Self.Q.Error](selected^.unwrap[Left[Self.T]]().into_payload()))))
        return Self.Out(Branch(Right(self.fallback^)))


struct Timeout[P: Machine, Q: Machine, prefer_source: Bool = False](Machine):
    comptime Value = Self.P.Value
    comptime Error = Self.P.Error
    comptime RaceType = Race[Self.P, Sleep[Self.Error], 2 if Self.prefer_source else 0]
    comptime Pipeline = Bind[Self.RaceType, _TimeoutBranch[Self.Value, Self.Q]]
    var program: Optional[Self.P]
    var fallback: Optional[Self.Q]
    var timer: Optional[Sleep[Self.Error]]
    var active: Optional[_Slot[Self.Pipeline, Self.Value, Self.Error]]

    def __init__(out self, var program: Self.P, duration: Int, var fallback: Self.Q):
        comptime assert Self.P.Value == Self.Q.Value and Self.P.Error == Self.Q.Error, "timeout fallback requires the same exact value and error types"
        self.program = Optional(program^)
        self.fallback = Optional(fallback^)
        self.timer = Optional(Sleep[Self.Error](duration))
        self.active = None

    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        if not self.active:
            self.timer.value()._start(context._clock.now())
            var pipeline = bind(Self.RaceType(self.program.take(), self.timer.take()), _TimeoutBranch[Self.Value, Self.Q](self.fallback.take()))
            self.active = Optional(_Slot[Self.Pipeline, Self.Value, Self.Error](pipeline^))
        _ = _tick(self.active.value(), context)
        if self.active.value().done():
            return .ready(self.active.value().take_outcome())
        return .pending(self.active.value().waiting())


def timeout_after[P: Machine, Q: Machine](var program: P, duration: Int, var fallback: Q) -> Timeout[P, Q]:
    return Timeout(program^, duration, fallback^)


def timeout_to[P: Machine, Q: Machine](var program: P, duration: Int, var fallback: Q) -> Timeout[P, Q, True]:
    return Timeout[P, Q, True](program^, duration, fallback^)
