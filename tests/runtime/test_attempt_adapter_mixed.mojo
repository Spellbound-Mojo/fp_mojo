"""Mixed adapters preserve reusable captures, exact errors and keyword names."""
from fp.data import Result, attempt, attempt_kwargs, raise_on_err
from fp.data import mutating, consuming, mut_owned, mut_owned_kwargs
from std.testing import assert_equal

@fieldwise_init
struct AttemptAdapterMixedInput(Movable):
    var value: Int

@fieldwise_init
struct AttemptAdapterMixedFailure(Movable):
    var code: Int

def forward_mixed[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable,
                  E: Movable & Deinitable, //, F: def(mut A, var B) raises E -> R](
    function: F, mut first: A, var second: B
) -> Result[R, E]:
    return attempt(mut_owned(function), first, second^)

def explicit_never(mut value: AttemptAdapterMixedInput) raises Never -> Int:
    value.value += 1
    return value.value

def consume_never(var value: AttemptAdapterMixedInput) raises Never -> Int:
    return value.value

def main() raises:
    var calls = 0
    var owner = AttemptAdapterMixedInput(5)
    @always_inline
    def pure(mut first: AttemptAdapterMixedInput, var second: AttemptAdapterMixedInput) {var owner^, mut calls} -> Int:
        calls += 1
        owner.value += 1
        first.value += second.value
        return first.value + owner.value
    var first = AttemptAdapterMixedInput(10)
    var view = mut_owned(pure)
    for i in range(3):
        var result = attempt(view, first, AttemptAdapterMixedInput(2))
        comptime assert type_of(result) == Result[Int, Never]
        assert_equal(raise_on_err(result^), 18 + 3 * i)
    assert_equal(first.value, 16)
    assert_equal(calls, 3)

    def fail(mut first: AttemptAdapterMixedInput, var second: AttemptAdapterMixedInput) raises AttemptAdapterMixedFailure {mut calls} -> Int:
        calls += 1
        first.value += second.value
        raise AttemptAdapterMixedFailure(first.value)
    var failed = forward_mixed(fail, first, AttemptAdapterMixedInput(4))
    comptime assert type_of(failed) == Result[Int, AttemptAdapterMixedFailure]
    var code = 0
    try: _ = raise_on_err(failed^)
    except error: code = error.code
    assert_equal(code, 20)
    assert_equal(first.value, 20)
    assert_equal(calls, 4)
    assert_equal(raise_on_err(attempt(mutating(explicit_never), first)), 21)
    assert_equal(raise_on_err(attempt(consuming(consume_never), AttemptAdapterMixedInput(17))), 17)

    def keywords(mut first: AttemptAdapterMixedInput, var second: AttemptAdapterMixedInput, /, var **values: Int) raises AttemptAdapterMixedFailure {mut calls} -> Int:
        calls += 1
        first.value += second.value + len(values)
        if len(values): raise AttemptAdapterMixedFailure(first.value)
        return first.value
    var empty = attempt_kwargs(mut_owned_kwargs(keywords), first, AttemptAdapterMixedInput(2))
    comptime assert type_of(empty) == Result[Int, AttemptAdapterMixedFailure]
    var observed: Int
    try: observed = raise_on_err(empty^)
    except error: raise Error("unexpected empty-pack error")
    assert_equal(observed, 23)
    var named = attempt_kwargs(mut_owned_kwargs(keywords), first, AttemptAdapterMixedInput(2), function=1, first=1, values=1)
    code = 0
    try: _ = raise_on_err(named^)
    except error: code = error.code
    assert_equal(code, 28)
    assert_equal(first.value, 28)
    assert_equal(calls, 6)
