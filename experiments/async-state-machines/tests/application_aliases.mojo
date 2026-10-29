"""Generic recipe names agree with family-selected composition and native callbacks."""
from std.builtin.rebind import downcast
from fp.algebra import tail_rec_m, BindContract, TailRecContract, Monad
from fp.callables import OnceUnary, Unary
from fp.data import ControlFlow, Continue, Break
from fp.functions import pipeline
from fp.effects._async.application import Pure, Bind, Loop, NativeDelay, pure, delay
from fp.effects._async.family import Async, Machine
from fp.effects._async.kernel import run
from foundation import check


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
    check(sequenced.take()._take_ok() == 42, "Bind names selected Pipeline flat_map")
    var loop: Loop[Repeat] = repeat[Async[Int]](Repeat(), 0)
    var repeated = run(loop^)
    check(repeated.take()._take_ok() == 100, "Loop names selected tail_rec_m")
    var plain = run(deferred[Int](answer))
    check(plain.take()._take_ok() == 42, "native delay generic alias")
    var captured = 41
    def add() {captured} -> Int:
        return captured + 1
    var owned = run(deferred[Int](add))
    check(owned.take()._take_ok() == 42, "native delay owns closure captures")
    var thin: def() thin -> Int = answer
    var pointer = run(delay[Int](thin))
    check(pointer.take()._take_ok() == 42, "native thin callback boundary")
    print("application aliases: generic Bind, Loop, NativeDelay, owned captures and thin callbacks")
