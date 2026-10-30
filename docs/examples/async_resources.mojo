"""Compose resource ownership and release in reverse acquisition order."""
from fp.effects import EffectFailure, fold_outcome
from fp.effects.async_runtime import IO, Resource, run


def release(value: Int) -> IO[NoneType, Int]:
    print("release:", value)
    return IO[NoneType, Int].pure(NoneType())


def next_resource(value: Int) -> Resource[Int, Int]:
    return Resource[Int, Int].make(IO[Int, Int].pure(value + 1), release)


def use(value: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(value * 2)


def success(value: Int) -> Int:
    return value


def failure(var errors: EffectFailure[Int]) -> Int:
    print("failed:", errors.errors.first(), "canceled:", errors.canceled)
    return -100


def canceled() -> Int:
    return -200


def main():
    var owned = Resource[Int, Int].make(IO[Int, Int].pure(20), release)
    var combined = owned^.flat_map(next_resource)
    print(fold_outcome(run(combined^.use(use)), success, failure, canceled))
