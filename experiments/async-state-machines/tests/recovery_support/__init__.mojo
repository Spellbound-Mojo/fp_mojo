"""Shared outcome fixtures for the recovery and materialization clients."""
from fp.effects import Outcome, EffectFailure, IOContext
from fp.data import Result, Ok, Err, NonEmptyList
from fp.effects._async.kernel import Machine, Step
from fp.effects._async.engine import IO


@fieldwise_init
struct Source(Machine):
    comptime Value = Int
    comptime Error = Int
    var value: Optional[Outcome[Int, Int]]
    var request: Bool
    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        if self.request:
            context.request_cancel()
        return .ready(self.value.take())


def source(mode: Int, request: Bool = False) -> IO[Int, Int]:
    var outcome: Outcome[Int, Int]
    if mode == 0:
        outcome = Optional(Result[Int, EffectFailure[Int]](Ok(42)))
    elif mode == 1:
        outcome = None
    else:
        var rest: List[Int] = [22]
        var errors = NonEmptyList(11, rest^)
        outcome = Optional(Result[Int, EffectFailure[Int]](Err(EffectFailure(errors^, mode == 3))))
    return IO[Int, Int].lift(Source(Optional(outcome^), request))
