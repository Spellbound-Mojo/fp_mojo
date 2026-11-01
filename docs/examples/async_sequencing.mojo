"""Sequence deferred native callbacks with IO and Pipeline."""
from fp.effects import EffectFailure, fold_outcome
from fp.effects.async_runtime import IO, run
from fp.functions import pipeline


def next_value(value: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(value + 2)


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
    var program = pipeline(IO[Int, Int].delay(initial)).flat_map(next_value).get()
    print(fold_outcome(run(program^), success, failure, canceled))
