"""Run a program on virtual time: a timeout completes without real waiting."""
from fp.effects import EffectFailure, fold_outcome
from fp.effects.async_runtime import IO, Duration, TestControl


def answer(var unit: NoneType) -> Int:
    return 42


def success(value: Int) -> Int:
    return value


def failure(var errors: EffectFailure[Int]) -> Int:
    return -1


def canceled() -> Int:
    return 0


def main() raises:
    var slow = IO[NoneType, Int].sleep(Duration.seconds(60)).map(answer)
    var program = slow^.timeout_to(Duration.seconds(5), IO[Int, Int].pure(7))
    var control = TestControl(program^)
    control.tick()
    print("next deadline in ms:", control.next_interval().value().to_nanoseconds() // 1_000_000)
    control.tick_all()
    print("result:", fold_outcome(control^.results(), success, failure, canceled))
