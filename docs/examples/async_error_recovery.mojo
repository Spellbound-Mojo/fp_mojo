"""Handle the complete noncanceled failure with a replacement IO."""
from fp.effects import EffectFailure, fold_outcome
from fp.effects.async_runtime import IO, run


def recover(var errors: EffectFailure[Int]) -> IO[Int, Int]:
    return IO[Int, Int].pure(errors.errors.first() + 1)


def success(value: Int) -> Int:
    return value


def failure(var errors: EffectFailure[Int]) -> Int:
    print("failed:", errors.errors.first(), "canceled:", errors.canceled)
    return -100


def canceled() -> Int:
    return -200


def main():
    var program = IO[Int, Int].raise_error(41).handle_error_with(recover)
    print(fold_outcome(run(program^), success, failure, canceled))
