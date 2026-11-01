"""Cats-style terminal operations return values and evaluate only the fallback branch."""
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from fp.callables import Unary, MutableUnary, OnceUnary, Thunk, MutableThunk, OnceThunk
from std.testing import assert_equal, assert_true, assert_false


def rt_ok() -> Result[Int, String]: return Ok(42)
def rt_err() -> Result[Int, String]: return Err(String("missing"))
def rt_length(var error: String) -> Int: return error.byte_length()
def rt_default() -> Int: return 7
def rt_never() raises Never -> Int: return 8
def rt_fail(var error: String) raises String -> Int: raise "raised: " + error
def rt_default_fail() raises Int -> Int: raise 91


@fieldwise_init
struct RTShared(Unary):
    comptime Arg = String
    comptime Out = Int
    def call(self, var error: String) -> Int: return error.byte_length()


@fieldwise_init
struct RTMutable(MutableUnary):
    var calls: Int
    comptime Arg = String
    comptime Out = Int
    def call_mut(mut self, var error: String) -> Int:
        self.calls += 1
        return error.byte_length() + self.calls


@fieldwise_init
struct RTOnce(OnceUnary):
    var value: Int
    comptime Arg = String
    comptime Out = Int
    def call_once(deinit self, var error: String) -> Int: return self.value


@fieldwise_init
struct RTSharedDefault(Thunk):
    comptime Out = Int
    def call(self) -> Int: return 11


@fieldwise_init
struct RTMutableDefault(MutableThunk):
    var value: Int
    comptime Out = Int
    def call_mut(mut self) -> Int:
        self.value += 1
        return self.value


@fieldwise_init
struct RTOnceDefault(OnceThunk):
    var value: Int
    comptime Out = Int
    def call_once(deinit self) -> Int: return self.value


def rt_pure() -> Int:
    # Pure and explicit raises-Never callbacks must remain usable without try.
    return rt_err().value_or(rt_length) + rt_err().get_or_else(rt_default) + rt_err().get_or_else(rt_never)


def rt_forward[T: Movable & Deinitable, E: Movable & Deinitable,
               X: Movable & Deinitable, //, F: def(var E) raises X -> T](
    var value: Result[T, E], callback: F
) raises X -> T:
    return pipeline(value^).raising[X]().value_or(callback)


def rt_forward_default[T: Movable & Deinitable, E: Movable & Deinitable,
                       X: Movable & Deinitable, //, F: def() raises X -> T](
    var value: Result[T, E], callback: F
) raises X -> T:
    return pipeline(value^).raising[X]().get_or_else(callback)


def main() raises:
    assert_equal(rt_pure(), 22)
    assert_equal(rt_ok().value_or(rt_length), 42)
    assert_equal(rt_ok().get_or_else(rt_default), 42)
    assert_equal(rt_err().value_or(RTShared()), 7)
    assert_equal(rt_err().value_or(RTMutable(1)), 9)
    assert_equal(rt_err().value_or(RTOnce(13)), 13)
    assert_equal(rt_err().get_or_else(RTSharedDefault()), 11)
    assert_equal(rt_err().get_or_else(RTMutableDefault(11)), 12)
    assert_equal(rt_err().get_or_else(RTOnceDefault(13)), 13)
    assert_equal(pipeline(rt_ok()).value_or(RTOnce(0)), 42)
    assert_equal(pipeline(rt_err()).get_or_else(RTOnceDefault(17)), 17)
    assert_equal(pipeline(rt_ok()).to_optional().value(), 42)

    var calls = 0
    def handler(var error: String) {mut calls} -> Int:
        calls += 1
        return error.byte_length()
    def factory() {mut calls} -> Int:
        calls += 10
        return 19
    assert_equal(rt_ok().value_or(handler), 42)
    assert_equal(rt_ok().get_or_else(factory), 42)
    assert_equal(calls, 0)
    assert_equal(rt_err().value_or(handler), 7)
    assert_equal(calls, 1)
    assert_equal(rt_err().get_or_else(factory), 19)
    assert_equal(calls, 11)

    def ordinary_error() raises {calls} -> Int:
        raise Error(String(calls))
    var ordinary_caught = False
    try: _ = rt_err().get_or_else(ordinary_error)
    except error:
        comptime assert type_of(error) == Error
        ordinary_caught = True
    assert_true(ordinary_caught)

    # Plain typed raising functions infer their effect directly on Result.
    var direct_code = 0
    try: _ = rt_err().get_or_else(rt_default_fail)
    except error:
        comptime assert type_of(error) == Int
        direct_code = error
    assert_equal(direct_code, 91)
    var direct_error = String()
    try: _ = rt_err().value_or(rt_fail)
    except error:
        comptime assert type_of(error) == String
        direct_error = error^
    assert_equal(direct_error, "raised: missing")

    for failed in range(2):
        var caught = False
        var output = 0
        var source = rt_err() if failed else rt_ok()
        try:
            output = rt_forward(source^, rt_fail)
        except error:
            comptime assert type_of(error) == String
            assert_equal(error, "raised: missing")
            caught = True
        assert_equal(caught, Bool(failed))
        if not failed: assert_equal(output, 42)
        caught = False
        var default_source = rt_err() if failed else rt_ok()
        try:
            output = rt_forward_default(default_source^, rt_default_fail)
        except error:
            comptime assert type_of(error) == Int
            assert_equal(error, 91)
            caught = True
        assert_equal(caught, Bool(failed))
        if not failed: assert_equal(output, 42)

    var some = rt_ok().to_optional()
    comptime assert type_of(some) == Optional[Int]
    assert_true(some)
    assert_equal(some.value(), 42)
    assert_false(rt_err().to_optional())
    assert_equal(Result[Int, Never](Ok(9)).get_or_else(rt_default), 9)
    assert_equal(Result[Int, Never](Ok(9)).to_optional().value(), 9)
    assert_false(Result[Never, Int](Err(1)).to_optional())
