from fp.data import Result, ok, err
from fp.functions import pipeline
from std.testing import assert_equal

@fieldwise_init
struct DefaultToken(Movable):
    var value: Int

def optional_default[T: Movable & Deinitable](var source: Optional[T], var fallback: T) -> T:
    return pipeline(source^).get_or(fallback^)

def result_default[T: Movable & Deinitable, E: Movable & Deinitable](
    var source: Result[T, E], var fallback: T
) -> T:
    return pipeline(source^).get_or(fallback^)

def pure_default() -> Int:
    # Selecting a native callback error does not add an effect to value extraction.
    return pipeline(Optional[Int]()).raising[String]().get_or(3) + err[Int]("bad").get_or(4)

def main() raises:
    assert_equal(pure_default(), 7)
    assert_equal(ok[String](3).get_or(0), 3)
    assert_equal(err[Int]("bad").get_or(0), 0)
    assert_equal(result_default(ok[String](5), 0), 5)
    assert_equal(result_default(err[Int]("bad"), 8), 8)
    assert_equal(optional_default(Optional(6), 0), 6)
    assert_equal(optional_default(Optional[Int](), 9), 9)
    # Expected payload types guide literal construction without explicit bindings.
    var direct = err[Float64]("bad").get_or(0)
    var selected = pipeline(err[Float64]("bad")).get_or(0)
    var optional = pipeline(Optional[Float64]()).get_or(0)
    comptime assert type_of(direct) == Float64
    comptime assert type_of(selected) == Float64
    comptime assert type_of(optional) == Float64
    assert_equal(direct + selected + optional, 0.0)
    assert_equal(pipeline(Optional[String]()).get_or("fallback"), "fallback")
    assert_equal(pipeline(err[String](1)).get_or("fallback"), "fallback")
    var token = pipeline(Optional[DefaultToken]()).get_or(DefaultToken(12))
    comptime assert type_of(token) == DefaultToken
    assert_equal(token.value, 12)
    var calls = 0
    def make_default() {mut calls} -> Int:
        calls += 1
        return 20
    assert_equal(ok[String](1).get_or(make_default()), 1)
    assert_equal(pipeline(ok[String](2)).get_or(make_default()), 2)
    assert_equal(pipeline(Optional(3)).get_or(make_default()), 3)
    assert_equal(calls, 3)
    assert_equal(err[Int]("bad").get_or(make_default()), 20)
    assert_equal(pipeline(err[Int]("bad")).get_or(make_default()), 20)
    assert_equal(pipeline(Optional[Int]()).get_or(make_default()), 20)
    assert_equal(calls, 6)
    # A present empty inner Optional stays a successful payload.
    var nested = pipeline(Optional[Optional[Int]](Optional[Int]())).get_or(Optional(7))
    assert_equal(Bool(nested), False)
    _ = pipeline(Optional[NoneType]()).get_or(NoneType())
