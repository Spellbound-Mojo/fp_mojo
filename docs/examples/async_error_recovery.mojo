"""Handle the complete noncanceled failure with an owned replacement recipe."""
from fp.effects import EffectFailure, fold_outcome
from fp.effects.async_runtime import Pure, pure, raise_error, handle_error_with, run


def recover(var errors: EffectFailure[Int]) -> Pure[Int, Int]:
    return pure[Int](errors.errors.first() + 1)


def success(value: Int) -> Int:
    return value


def failure(var errors: EffectFailure[Int]) -> Int:
    print("failed:", errors.errors.first(), "canceled:", errors.canceled)
    return -100


def canceled() -> Int:
    return -200


def main():
    var program = handle_error_with(raise_error[Int, Int](41), recover)
    print(fold_outcome(run(program^), success, failure, canceled))
