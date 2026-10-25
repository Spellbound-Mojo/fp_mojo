"""Adapters preserve native no-value, NoneType and explicit Never signatures."""
from fp.data import Result, attempt, attempt_kwargs, mutating, consuming, mut_owned, mut_owned_kwargs
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
    var pure = attempt(mutating(mutable_pure), value)
    comptime assert type_of(pure) == Result[type_of(None), Never]
    assert_equal(pure.is_ok(), True)
    assert_equal(attempt(mutating(mutable_never), value).is_ok(), True)
    check(attempt(mutating(mutable_raising), value), 0)
    assert_equal(value, 3)
    value = -10
    check(attempt(mutating(mutable_raising), value), -9)
    assert_equal(value, -9)

    assert_equal(attempt(consuming(owned_pure), 1).is_ok(), True)
    assert_equal(attempt(consuming(owned_never), 1).is_ok(), True)
    check(attempt(consuming(owned_raising), 1), 0)
    check(attempt(consuming(owned_raising), -7), -7)

    value = 0
    assert_equal(attempt(mut_owned(mixed_pure), value, 2).is_ok(), True)
    assert_equal(attempt(mut_owned(mixed_never), value, 2).is_ok(), True)
    check(attempt(mut_owned(mixed_raising), value, 2), 0)
    assert_equal(value, 6)
    check(attempt(mut_owned(mixed_raising), value, -10), -4)
    assert_equal(value, -4)

    value = 0
    assert_equal(attempt_kwargs(mut_owned_kwargs(keywords_pure), value, 2, one=1).is_ok(), True)
    assert_equal(attempt_kwargs(mut_owned_kwargs(keywords_never), value, 2).is_ok(), True)
    check(attempt_kwargs(mut_owned_kwargs(keywords_raising), value, 2, one=1), 0)
    assert_equal(value, 8)
    check(attempt_kwargs(mut_owned_kwargs(keywords_raising), value, -10), -2)
    assert_equal(value, -2)

    var explicit = attempt(mutating(explicit_none), value)
    comptime assert type_of(explicit) == Result[NoneType, Never]
    assert_equal(explicit.is_ok(), True)
