"""Native functions and closures as algebra and effect callbacks, without promotion."""
from fp.algebra import (map, flat_map, traverse, pure, IdentityFamily, OptionalFamily, ResultFamily,
    ListFamily, StringMonoid)
from fp.effects import State, Reader, Writer, run, get, modify, censor, writer, run_writer, local, action
from fp.callables import BorrowCallable
from fp.data import Result, Ok, Err
from std.testing import assert_equal, assert_true, assert_false


def twice(value: Int) -> Int:
    return value * 2


def positive(value: Int) -> Optional[Int]:
    return Optional(value) if value > 0 else Optional[Int]()


def halve(value: Int) -> Result[Int, String]:
    if value % 2:
        return Err(String("odd"))
    return Ok(value // 2)


def tag(var text: String) -> String:
    return text + "!"


@fieldwise_init
struct Bad(Movable, Writable):
    var code: Int


def checked(value: Int) raises Bad -> Int:
    if value < 0:
        raise Bad(value)
    return value


@fieldwise_init
struct Environment(Movable):
    var value: Int


@fieldwise_init
struct ReadEnvironment(BorrowCallable, Defaultable):
    comptime Payload = Environment
    comptime Result = Int
    def invoke(self, ref environment: Environment) raises Never capturing -> Int:
        return environment.value


def grow(environment: Environment) -> Environment:
    return Environment(environment.value + 2)


def instances() raises:
    assert_equal(map[IdentityFamily](twice, 3), 6)
    assert_equal(map[OptionalFamily](twice, Optional(3)).value(), 6)
    assert_false(Bool(map[OptionalFamily](twice, Optional[Int]())))
    var xs: List[Int] = [1, 2, 3]
    var doubled = map[ListFamily](twice, xs^)
    assert_equal(doubled[2], 6)
    assert_true(map[ResultFamily[String]](twice, Result[Int, String](Ok(4))).is_ok())
    assert_false(Bool(flat_map[OptionalFamily](positive, Optional(-1))))
    assert_equal(flat_map[ResultFamily[String]](halve, Result[Int, String](Ok(8))).raise_on_err(), 4)
    var valid: List[Int] = [1, 2]
    assert_equal(len(traverse[ListFamily, OptionalFamily](positive, valid^).value()), 2)
    var invalid: List[Int] = [1, -2]
    assert_false(Bool(traverse[ListFamily, OptionalFamily](positive, invalid^)))
    # Closures keep their captures; the callback is borrowed, not copied.
    var calls = 0
    def counted(value: Int) {mut calls} -> Int:
        calls += 1
        return value + 1
    var ys: List[Int] = [1, 2, 3]
    assert_equal(map[ListFamily](counted, ys^)[2], 4)
    assert_equal(calls, 3)
    # A raising callback keeps its exact error type.
    var code = 0
    var zs: List[Int] = [1, -7, 3]
    try:
        _ = map[ListFamily](checked, zs^)
    except error:
        comptime assert type_of(error) == Bad
        code = error.code
    assert_equal(code, -7)


def effects() raises:
    assert_equal(run[State[Int]](modify[State[Int]](twice), 21)[1], 42)
    assert_equal(run[State[Int]](map[State[Int]](twice, get[State[Int]]()), 4)[0], 8)
    comptime W = Writer[StringMonoid]
    var logged = run_writer[W](censor[W](tag, writer[W, Int](Tuple(String("a"), 1))))
    assert_equal(logged[0], "a!")
    var environment = Environment(5)
    var source = action[Reader[Environment], Int](ReadEnvironment())
    assert_equal(run[Reader[Environment]](local[Reader[Environment]](grow, source^), environment), 7)
    assert_equal(environment.value, 5)
    var step = 3
    def bump(value: Int) {imm step} -> Int:
        return value + step
    assert_equal(run[State[Int]](modify[State[Int]](bump), 1)[1], 4)


def main() raises:
    instances()
    effects()
    print("native algebra: instances, transformers and effect callbacks")
