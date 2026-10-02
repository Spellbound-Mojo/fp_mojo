"""Generic Result processing keeps domain failures separate from raised failures."""
from fp.data import Result, Ok, Err
from std.testing import assert_equal


def mapped[T: Movable & Deinitable, E: Movable & Deinitable,
           U: Movable & Deinitable, X: Movable & Deinitable, //,
           F: def(var T) raises X -> U](
    var value: Result[T, E], callback: F
) raises X -> Result[U, E]:
    return value^.map[X=X](callback)


def forwarded[T: Movable & Deinitable, E: Movable & Deinitable,
              U: Movable & Deinitable, X: Movable & Deinitable, //,
              F: def(var T) raises X -> U](
    var value: Result[T, E], callback: F
) raises X -> Result[U, E]:
    return mapped[X=X](value^, callback)


@fieldwise_init
struct Domain(Movable):
    var code: Int
@fieldwise_init
struct ProcessingFailure(Movable):
    var code: Int
@fieldwise_init
struct Notice(Movable):
    var code: Int


def accepted(var value: Int) -> Result[String, Domain]:
    if value < 10: return Err(Domain(40))
    return Ok(String("accepted"))

def explain(var error: Domain) -> Notice:
    return Notice(error.code + 100)

def recover(var error: Notice) -> Result[String, Never]:
    return Ok("notice " + String(error.code))


def main() raises:
    var calls = 0
    def process(var value: Int) raises ProcessingFailure {mut calls} -> Int:
        calls += 1
        if value < 0: raise ProcessingFailure(90)
        return value * 2
    for mode in range(3):
        var source = Result[Int, Domain](Err(Domain(7))) if mode == 1 else Result[Int, Domain](Ok(6 if mode == 0 else -1))
        var outcome: String
        try:
            var mapped_value = forwarded(source^, process)
            outcome = mapped_value^.flat_map(accepted).map_err(explain).or_else(recover).raise_on_err()
        except failure:
            comptime assert type_of(failure) == ProcessingFailure
            outcome = "raised " + String(failure.code)
        assert_equal(outcome, "accepted" if mode == 0 else "notice 107" if mode == 1 else "raised 90")
        print(outcome)
    assert_equal(calls, 2)
