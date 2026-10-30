"""Resource composes ownership as IO: projection, dependent resources and borrowed bodies."""
from std.os import abort
from fp.effects import Outcome, EffectFailure, fold_outcome
from fp.effects.async_runtime import IO, Resource, run
from fp.callables import BorrowOnceCallable, BorrowSignature


def release(value: Int) -> IO[NoneType, Int]:
    return IO[NoneType, Int].pure(NoneType())


def body(value: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(value + 2)


@fieldwise_init
struct Double(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Int
    def invoke_once(deinit self, ref value: Int) -> Int:
        return value * 2


@fieldwise_init
struct Next(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Resource[Int, Int]
    def invoke_once(deinit self, ref value: Int) -> Self.Result:
        return Resource[Int, Int].make(IO[Int, Int].pure(value + 1), release)


@fieldwise_init
struct Body(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = IO[Int, Int]
    def invoke_once(deinit self, ref value: Int) -> Self.Result:
        return IO[Int, Int].pure(value + 2)


def main():
    var resource = Resource[Int, Int].make(IO[Int, Int].pure(19), release)
    var outcome = run(resource^.flat_map(Next()).map(Double()).use(Body()))
    if take_int(outcome^) != 42:
        abort("resource composition")
    var pointer: def(Int) thin -> IO[Int, Int] = body
    var native = BorrowSignature[Int, IO[Int, Int]].capture(pointer)
    var second = Resource[Int, Int].make(IO[Int, Int].pure(40), release)
    var result = run(second^.use(native^))
    if take_int(result^) != 42:
        abort("borrowed body factory")
    print("resource composition: borrowed projection, dependent resources, borrowed body, native body factory")


def success(value: Int) -> Int:
    return value


def failure(var value: EffectFailure[Int]) -> Int:
    abort("unexpected failure")


def canceled() -> Int:
    abort("unexpected cancellation")


def take_int(var outcome: Outcome[Int, Int]) -> Int:
    return fold_outcome(outcome^, success, failure, canceled)
