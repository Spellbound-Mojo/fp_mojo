"""Adapters preserve native no-value, NoneType and explicit Never signatures."""
from fp.data import Capture, Result
from std.testing import assert_equal

@fieldwise_init
struct AttemptAdapterVoidFailure(Movable):
    var code: Int

def mutable_pure(mut value: Int):
    value += 1

def mutable_never(mut value: Int) raises Never:
    value += 1

def mutable_raising(mut value: Int) raises AttemptAdapterVoidFailure:
    value += 1
    if value < 0: raise AttemptAdapterVoidFailure(value)

def owned_pure(var value: Int):
    _ = value

def owned_never(var value: Int) raises Never:
    _ = value

def owned_raising(var value: Int) raises AttemptAdapterVoidFailure:
    if value < 0: raise AttemptAdapterVoidFailure(value)

def mixed_pure(mut value: Int, var amount: Int):
    value += amount

def mixed_never(mut value: Int, var amount: Int) raises Never:
    value += amount

def mixed_raising(mut value: Int, var amount: Int) raises AttemptAdapterVoidFailure:
    value += amount
    if value < 0: raise AttemptAdapterVoidFailure(value)

def keywords_pure(mut value: Int, var amount: Int, /, var **options: Int):
    value += amount + len(options)

def keywords_never(mut value: Int, var amount: Int, /, var **options: Int) raises Never:
    value += amount + len(options)

def keywords_raising(mut value: Int, var amount: Int, /, var **options: Int) raises AttemptAdapterVoidFailure:
    value += amount + len(options)
    if value < 0: raise AttemptAdapterVoidFailure(value)

def explicit_none(mut value: Int) -> NoneType:
    value += 1
    return None

def check(var result: Result[type_of(None), AttemptAdapterVoidFailure], expected: Int) raises:
    var caught = 0
    try: _ = result^.raise_on_err()
    except error: caught = error.code
    assert_equal(caught, expected)

def main() raises:
    var value = 0
    var pure = Capture.mutable(value).run(mutable_pure)
    comptime assert type_of(pure) == Result[type_of(None), Never]
    assert_equal(pure.is_ok(), True)
    assert_equal(Capture.mutable(value).run(mutable_never).is_ok(), True)
    check(Capture.mutable(value).run(mutable_raising), 0)
    assert_equal(value, 3)
    value = -10
    check(Capture.mutable(value).run(mutable_raising), -9)
    assert_equal(value, -9)

    assert_equal(Capture.take(1).run(owned_pure).is_ok(), True)
    assert_equal(Capture.take(1).run(owned_never).is_ok(), True)
    check(Capture.take(1).run(owned_raising), 0)
    check(Capture.take(-7).run(owned_raising), -7)

    value = 0
    assert_equal(Capture.mutable(value).take(2).run(mixed_pure).is_ok(), True)
    assert_equal(Capture.mutable(value).take(2).run(mixed_never).is_ok(), True)
    check(Capture.mutable(value).take(2).run(mixed_raising), 0)
    assert_equal(value, 6)
    check(Capture.mutable(value).take(-10).run(mixed_raising), -4)
    assert_equal(value, -4)

    value = 0
    assert_equal(Capture.mutable(value).take(2).kwargs(one=1).run(keywords_pure).is_ok(), True)
    assert_equal(Capture.mutable(value).take(2).kwargs[K=Int]().run(keywords_never).is_ok(), True)
    check(Capture.mutable(value).take(2).kwargs(one=1).run(keywords_raising), 0)
    assert_equal(value, 8)
    check(Capture.mutable(value).take(-10).kwargs[K=Int]().run(keywords_raising), -2)
    assert_equal(value, -2)

    var explicit = Capture.mutable(value).run(explicit_none)
    comptime assert type_of(explicit) == Result[NoneType, Never]
    assert_equal(explicit.is_ok(), True)
