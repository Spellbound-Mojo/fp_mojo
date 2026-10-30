"""Sequence deferred native callbacks with the selected Async family."""
from fp.effects import EffectFailure, fold_outcome
from fp.effects.async_runtime import pure, Pure, delay, run
from fp.functions import pipeline


def next_value(value: Int) -> Pure[Int, Int]:
    return pure[Int](value + 2)


def initial() -> Int:
    return 40


def success(value: Int) -> Int:
    return value


def failure(var errors: EffectFailure[Int]) -> Int:
    print("failed:", errors.errors.first(), "canceled:", errors.canceled)
    return -100


def canceled() -> Int:
    return -200


def main():
    var program = pipeline(delay[Int](initial)).flat_map(next_value).get()
    print(fold_outcome(run(program^), success, failure, canceled))
