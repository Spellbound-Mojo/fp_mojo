"""Iterate with one owned state and one current asynchronous step."""
from fp.algebra import tail_rec_m
from fp.callables import Unary
from fp.data import ControlFlow, Continue, Break
from fp.effects import EffectFailure, fold_outcome
from fp.effects.async_runtime import Async, Pure, pure, run


@fieldwise_init
struct Increment(Unary):
    comptime Arg = Int
    comptime Out = Pure[ControlFlow[Int, Int], Int]
    def call(self, var state: Int) -> Self.Out:
        if state == 42:
            return pure[Int](ControlFlow[Int, Int](Break(state)))
        return pure[Int](ControlFlow[Int, Int](Continue(state + 1)))


def success(value: Int) -> Int:
    return value


def failure(var errors: EffectFailure[Int]) -> Int:
    print("failed:", errors.errors.first(), "canceled:", errors.canceled)
    return -100


def canceled() -> Int:
    return -200


def main():
    var program = tail_rec_m[Async[Int]](Increment(), 0)
    print(fold_outcome(run(program^), success, failure, canceled))
