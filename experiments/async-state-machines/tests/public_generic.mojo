"""Generic recipe names agree with family-selected composition and native callbacks."""
from std.os import abort
from fp.effects import Outcome, EffectFailure, fold_outcome
from fp.algebra import tail_rec_m, BindContract, TailRecContract, Monad
from fp.callables import OnceUnary, Unary
from fp.data import ControlFlow, Continue, Break
from fp.functions import pipeline
from fp.effects.async_runtime import Pure, Bind, Loop, NativeDelay, pure, delay, Async, run


def chain[I: Monad, P: Movable & Deinitable, F: OnceUnary](var source: P, var function: F) raises BindContract[I, P, F].Error -> BindContract[I, P, F].Out where F.Arg == I.Element[P] and BindContract[I, P, F].FamilyCompatible:
    return pipeline[I](source^).flat_map(function^).get()


def deferred[T: Movable & Deinitable, //, E: Movable & Deinitable, F: def() -> T](var function: F) -> NativeDelay[T, E, F]:
    return delay[E](function^)


@fieldwise_init
struct Next(OnceUnary):
    comptime Arg = Int
    comptime Out = Pure[Int, Int]
    def call_once(deinit self, var value: Int) -> Self.Out:
        return pure[Int](value + 1)


@fieldwise_init
struct Repeat(Unary):
    comptime Arg = Int
    comptime Out = Pure[ControlFlow[Int, Int], Int]
    def call(self, var value: Int) -> Self.Out:
        var control = ControlFlow[Int, Int](Break(value)) if value == 100 else ControlFlow[Int, Int](Continue(value + 1))
        return pure[Int](control^)


def repeat[I: Monad, F: Unary](var step: F, var initial: F.Arg) raises TailRecContract[I, F].Error -> TailRecContract[I, F].Out where TailRecContract[I, F].Compatible:
    return tail_rec_m[I](step^, initial^)


def answer() -> Int:
    return 42


def main() raises:
    var bound: Bind[Pure[Int, Int], Next] = chain[Async[Int]](pure[Int](41), Next())
    var sequenced = run(bound^)
    check(take_int(sequenced^) == 42, "Bind names selected Pipeline flat_map")
    var loop: Loop[Repeat] = repeat[Async[Int]](Repeat(), 0)
    var repeated = run(loop^)
    check(take_int(repeated^) == 100, "Loop names selected tail_rec_m")
    var plain = run(deferred[Int](answer))
    check(take_int(plain^) == 42, "native delay generic alias")
    var captured = 41
    def add() {captured} -> Int:
        return captured + 1
    var owned = run(deferred[Int](add))
    check(take_int(owned^) == 42, "native delay owns closure captures")
    var thin: def() thin -> Int = answer
    var pointer = run(delay[Int](thin))
    check(take_int(pointer^) == 42, "native thin callback boundary")
    print("application aliases: generic Bind, Loop, NativeDelay, owned captures and thin callbacks")


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
