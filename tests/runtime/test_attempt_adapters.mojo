"""Borrowed adapters retain mutable and owned native conventions."""
from fp.data import Capture, Result, raise_on_err
from std.testing import assert_equal

@fieldwise_init
struct AttemptAdapterInput(Movable):
    var value: Int

@fieldwise_init
struct AttemptAdapterFailure(Movable):
    var code: Int

def update(mut value: AttemptAdapterInput) -> Int:
    value.value += 1
    return value.value

def fail(mut value: AttemptAdapterInput) raises AttemptAdapterFailure -> Int:
    value.value += 2
    raise AttemptAdapterFailure(value.value)

def consume(var value: AttemptAdapterInput) -> Int:
    return value.value

def forward[A: Movable & Deinitable, R: Movable & Deinitable, //,
            F: def(var A) -> R](function: F, var value: A) -> Result[R, Never]:
    return Capture.take(value^).run(function)

def main() raises:
    var value = AttemptAdapterInput(7)
    var updated = Capture.mutable(value).run(update)
    comptime assert type_of(updated) == Result[Int, Never]
    assert_equal(raise_on_err(updated^), 8)
    var failed = Capture.mutable(value).run(fail)
    comptime assert type_of(failed) == Result[Int, AttemptAdapterFailure]
    var code = 0
    try: _ = raise_on_err(failed^)
    except error: code = error.code
    assert_equal(code, 10)
    assert_equal(value.value, 10)
    assert_equal(raise_on_err(Capture.take(value^).run(consume)), 10)
    assert_equal(raise_on_err(forward(consume, AttemptAdapterInput(12))), 12)
