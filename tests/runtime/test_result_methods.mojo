"""Result methods and implicit Ok/Err conversion."""
from fp.data import Result, Ok, Err
from fp.functions import partial, flow
from fp.callables import OnceUnary
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true, assert_false


@fieldwise_init
struct Problem(Movable, Writable):
    var message: String


@fieldwise_init
struct MethodToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1


def parse(text: String) -> Result[Int, Problem]:
    if text == "":
        return Err(Problem("empty"))
    return Ok(text.byte_length())


def twice(value: Int) -> Int:
    return value * 2


def half(value: Int) -> Result[Int, Problem]:
    if value % 2:
        return Err(Problem("odd"))
    return Ok(value // 2)


def describe(problem: Problem) -> String:
    return "problem: " + problem.message


def recover(problem: Problem) -> Result[Int, String]:
    return Ok(0)


def add(a: Int, b: Int) -> Int:
    return a + b


@fieldwise_init
struct MethodError(Movable, Writable):
    var code: Int


def strict(value: Int) raises MethodError -> Int:
    raise MethodError(value)


def strict_error(problem: Problem) raises MethodError -> String:
    raise MethodError(problem.message.byte_length())


@fieldwise_init
struct Once(OnceUnary):
    var bias: Int
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var arg: Int) -> Int:
        return arg + self.bias


def forward_map[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //,
                F: def(var T) raises X -> U](var value: Result[T, E], callback: F) raises X -> Result[U, E]:
    return value^.map[X=X](callback)


def construction() raises:
    var ok: Result[Int, String] = Ok(3)
    var err: Result[Int, String] = Err(String("x"))
    assert_true(ok.is_ok())
    assert_true(err.is_err())
    var same: Result[Int, Int] = Err(3)
    assert_true(same.is_err())
    assert_true(parse("ab").is_ok())
    assert_true(parse("").is_err())


def transformations() raises:
    assert_equal(parse("abcd").map(twice).flat_map(half).raise_on_err(), 4)
    var failed = parse("abc").flat_map(half).map_err(describe)
    assert_true(failed.is_err())
    comptime assert type_of(failed) == Result[Int, String]
    assert_equal(parse("").or_else(recover).raise_on_err(), 0)
    assert_equal(parse("ab").map(partial(add, 10)).raise_on_err(), 12)
    assert_equal(parse("ab").map(flow(twice, twice)).raise_on_err(), 8)
    assert_equal(parse("ab").map(Once(5)).raise_on_err(), 7)
    var k = 1
    def plus(value: Int) {imm k} -> Int:
        return value + k
    assert_equal(parse("x").map(plus).raise_on_err(), 2)


def errors() raises:
    var code = 0
    try:
        _ = parse("abc").map(strict)
    except error:
        comptime assert type_of(error) == MethodError
        code = error.code
    assert_equal(code, 3)
    try:
        _ = parse("").map_err(strict_error)
    except error:
        code = error.code
    assert_equal(code, 5)
    try:
        _ = forward_map(parse("abcde"), strict)
    except error:
        code = error.code
    assert_equal(code, 5)
    # The callback on the other branch never runs.
    assert_true(parse("").map(strict).is_err())


def ownership() raises:
    var drops = ArcPointer(0)
    var calls = 0
    def wrap(value: Int) {mut calls, drops} -> MethodToken:
        calls += 1
        return MethodToken(value, drops)
    def unwrap(var token: MethodToken) -> Int:
        return token.value
    var mapped = parse("abc").map(wrap)
    assert_equal(calls, 1)
    assert_equal(drops[], 0)
    assert_equal(mapped^.map(unwrap).raise_on_err(), 3)
    assert_equal(drops[], 1)
    _ = parse("").map(wrap)
    assert_equal(calls, 1)


def main() raises:
    construction()
    transformations()
    errors()
    ownership()
    print("result methods: map, flat_map, map_err, or_else and implicit Ok/Err")
