"""Whole Tuple/Result values, nested attempt channels, Never and StopIteration."""
from fp.functions import as_unary, pipe
from fp.data import Result, Err, attempt
from std.testing import assert_equal

def pair(var value: Int) raises Int -> Tuple[Int, String]:
    if value < 0: raise value
    return (value, String("pair"))

def whole(var value: Tuple[Int, String]) raises Never -> Result[Int, String]:
    return Result[Int, String](Err(String(value[1])))

def observe(var value: Result[Int, String]) -> Bool: return value.is_err()

def nested(var value: Int) raises Int -> Result[Int, String]:
    var a = as_unary(pair)
    var b = as_unary(whole)
    return pipe(value, a, b)

def stop(var value: Int) raises StopIteration -> Int:
    if value == 0: raise StopIteration()
    return value

def same(var value: Int) raises Never -> Int: return value

def pure_context() -> Int:
    var a = as_unary(same)
    # An all-Never inferred channel requires no raising context.
    return pipe(4, a, a)

def main() raises:
    var a = as_unary(pair)
    var b = as_unary(whole)
    var c = as_unary(observe)
    var observed = False
    try: observed = pipe(3, a, b, c)
    except _: pass
    assert_equal(observed, True)
    var ok = attempt(nested, 3)
    assert_equal(ok.is_ok(), True)
    var inner_error = False
    try: inner_error = ok^.raise_on_err().is_err()
    except _: pass
    assert_equal(inner_error, True)
    var err = attempt(nested, -7)
    assert_equal(err.is_err(), True)
    var code = 0
    try: _ = err^.raise_on_err()
    except error: code = error
    assert_equal(code, -7)
    var stopping = as_unary(stop)
    var neutral = as_unary(same)
    var value = 0
    try: value = pipe(3, neutral, stopping, neutral)
    except _: pass
    assert_equal(value, 3)
    var caught = False
    try: _ = pipe(0, neutral, stopping, neutral)
    except _: caught = True
    assert_equal(caught, True)
    assert_equal(pure_context(), 4)
    assert_equal(pipe(2), 2)
    assert_equal(pipe(2, same), 2)
