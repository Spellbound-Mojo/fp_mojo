"""Race results and the canonical selection of winning and losing outcomes."""
from fp.adt.data import Cases, Choice, Data, Value
from fp.data import Left, Right, Result, Ok, Err
from fp.effects import Outcome, EffectFailure
from fp.effects.outcomes import _failure_as


struct _RaceCases[A: Movable & Deinitable, B: Movable & Deinitable](Data):
    comptime Layer[R: Value] = Cases[Left[Self.A], Right[Self.B]]


comptime RaceResult[A: Movable & Deinitable, B: Movable & Deinitable] = Choice[_RaceCases[A, B]]
"""The canonical Choice of Left[A] or Right[B] selected by a structured race.

Parameters:
    A: The exact left success value.
    B: The exact right success value.
"""


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
