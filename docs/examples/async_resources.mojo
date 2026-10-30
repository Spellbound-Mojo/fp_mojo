"""Compose resource ownership and release in reverse acquisition order."""
from fp.effects import EffectFailure, fold_outcome
from fp.effects.async_runtime import pure, Pure, resource, run


def release(value: Int) -> Pure[NoneType, Int]:
    print("release:", value)
    return pure[Int](NoneType())


def next_resource(value: Int) -> type_of(resource(pure[Int](value), release)):
    return resource(pure[Int](value + 1), release)


def use(value: Int) -> Pure[Int, Int]:
    return pure[Int](value * 2)


def success(value: Int) -> Int:
    return value


def failure(var errors: EffectFailure[Int]) -> Int:
    print("failed:", errors.errors.first(), "canceled:", errors.canceled)
    return -100


def canceled() -> Int:
    return -200


def main():
    var owned = resource(pure[Int](20), release)
    var combined = owned^.flat_map(next_resource)
    print(fold_outcome(run(combined^.use(use)), success, failure, canceled))
