"""Generic wrappers return IO through public family contracts; native thin callbacks."""
from std.os import abort
from fp.effects import Outcome, EffectFailure, fold_outcome
from fp.algebra import tail_rec_m, BindContract, TailRecContract, Monad
from fp.callables import OnceUnary, Unary
from fp.data import ControlFlow, Continue, Break
from fp.functions import pipeline
from fp.effects.async_runtime import IO, Async, run


def chain[I: Monad, P: Movable & Deinitable, F: OnceUnary](var source: P, var function: F) raises BindContract[I, P, F].Error -> BindContract[I, P, F].Out where F.Arg == I.Element[P] and BindContract[I, P, F].FamilyCompatible:
    return pipeline[I](source^).flat_map(function^).get()


@fieldwise_init
struct Next(OnceUnary):
    comptime Arg = Int
    comptime Out = IO[Int, Int]
    def call_once(deinit self, var value: Int) -> Self.Out:
        return Self.Out.pure(value + 1)


@fieldwise_init
struct Repeat(Unary):
    comptime Arg = Int
    comptime Out = IO[ControlFlow[Int, Int], Int]
    def call(self, var value: Int) -> Self.Out:
        var control = ControlFlow[Int, Int](Break(value)) if value == 100 else ControlFlow[Int, Int](Continue(value + 1))
        return Self.Out.pure(control^)


def repeat[I: Monad, F: Unary](var step: F, var initial: F.Arg) raises TailRecContract[I, F].Error -> TailRecContract[I, F].Out where TailRecContract[I, F].Compatible:
    return tail_rec_m[I](step^, initial^)


def answer() -> Int:
    return 42


def main() raises:
    var bound: IO[Int, Int] = chain[Async[Int]](IO[Int, Int].pure(41), Next())
    check(take_int(run(bound^)) == 42, "generic Pipeline flat_map returns IO")
    var loop: IO[Int, Int] = repeat[Async[Int]](Repeat(), 0)
    check(take_int(run(loop^)) == 100, "generic tail_rec_m returns IO")
    check(take_int(run(IO[Int, Int].delay(answer))) == 42, "native delay")
    var thin: def() thin -> Int = answer
    check(take_int(run(IO[Int, Int].delay(thin))) == 42, "native thin callback boundary")
    print("io generic: Pipeline and tail_rec_m return IO through public contracts, native thin callbacks")


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def success(value: Int) -> Int:
    return value


def failure(var value: EffectFailure[Int]) -> Int:
    abort("unexpected failure")


def canceled() -> Int:
    abort("unexpected cancellation")


def take_int(var outcome: Outcome[Int, Int]) -> Int:
    return fold_outcome(outcome^, success, failure, canceled)
