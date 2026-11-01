"""Adapted calls separate stored Results from native errors and no-value returns."""
from fp.data import Capture, Result, Ok, Err, raise_on_err
from std.testing import assert_equal

@fieldwise_init
struct AttemptAdapterResultFailure(Movable):
    var code: Int

def nested(mut value: Int) raises AttemptAdapterResultFailure -> Result[Int, AttemptAdapterResultFailure]:
    value += 1
    if value == 3: raise AttemptAdapterResultFailure(30)
    return Result[Int, AttemptAdapterResultFailure](Err(AttemptAdapterResultFailure(10 * value)))

def stop(mut value: Int) raises StopIteration -> Int:
    value += 1
    raise StopIteration()

def mutate_void(mut value: Int):
    value += 2

def own_void(var value: String):
    _ = value.byte_length()

def main() raises:
    var value = 0
    for expected in range(1, 4):
        var result = Capture.mutable(value).run(nested)
        comptime assert type_of(result) == Result[Result[Int, AttemptAdapterResultFailure], AttemptAdapterResultFailure]
        var native_code = 0
        var stored_code = 0
        try:
            var inner = raise_on_err(result^)
            try: _ = raise_on_err(inner^)
            except error: stored_code = error.code
        except error: native_code = error.code
        assert_equal(native_code, 30 if expected == 3 else 0)
        assert_equal(stored_code, 10 * expected if expected < 3 else 0)
        assert_equal(value, expected)
    var stopped = Capture.mutable(value).run(stop)
    comptime assert type_of(stopped) == Result[Int,StopIteration]
    assert_equal(stopped.is_err(), True)
    assert_equal(value, 4)
    var void_result = Capture.mutable(value).run(mutate_void)
    assert_equal(void_result.is_ok(), True)
    assert_equal(value, 6)
    var owned_void = Capture.take(String("text")).run(own_void)
    assert_equal(owned_void.is_ok(), True)
