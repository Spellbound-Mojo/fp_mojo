"""Native keyword packs preserve Result channels, scalar prefixes and dictionary expansion."""
from fp.data import Result, Ok, Err, attempt, raise_on_err
from std.collections import StringDict
from std.testing import assert_equal

@fieldwise_init
struct Token(Movable):
    var value: Int

@fieldwise_init
struct InnerFailure(Movable):
    var code: Int

@fieldwise_init
struct OuterFailure(Movable):
    var code: Int

comptime Item = Result[Token, InnerFailure]

def stored(var **values: Int) -> Item:
    var code = 0
    for entry in values.items(): code += entry.value
    if code < 0: return Item(Err(InnerFailure(17)))
    return Item(Ok(Token(code)))

def fallible(first: Int, second: Int, /, var **values: Int) raises OuterFailure -> Item:
    var fail = False
    for entry in values.items():
        if entry.key == "fail": fail = Bool(entry.value)
    if fail: raise OuterFailure(42)
    values["prefix"] = first * 10 + second
    return stored(**values^)

def total(var **values: Int) -> Int:
    var result = 0
    for entry in values.items(): result += entry.key.byte_length() * entry.value
    return result

def forward(var **values: Int) -> Result[Int, Never]:
    return attempt(total, **values^)

def main() raises:
    var ordinary: Result[Item, Never] = attempt(stored, code=-1)
    assert_equal(ordinary.is_ok(), True)
    var item = raise_on_err(ordinary^)
    assert_equal(item.is_err(), True)
    var code = 0
    try: _ = raise_on_err(item^)
    except error: code = error.code
    assert_equal(code, 17)

    for fail in range(2):
        for value in range(-24, -21):
            var result: Result[Item, OuterFailure] = attempt(fallible, 2, 3, code=value, fail=fail)
            assert_equal(result.is_err(), Bool(fail))
            var outer_code = 0
            var selected: Optional[Item] = None
            try: selected = Optional(raise_on_err(result^))
            except error: outer_code = error.code
            assert_equal(outer_code, 42 if fail else 0)
            if not fail:
                var inner = selected.take()
                assert_equal(inner.is_err(), value + 23 < 0)
                var inner_code = 0
                var observed = -1
                try:
                    var token = raise_on_err(inner^)
                    observed = token.value
                except error: inner_code = error.code
                assert_equal(inner_code, 17 if value + 23 < 0 else 0)
                if value + 23 >= 0: assert_equal(observed, value + 23)

    var values = StringDict[Int]()
    values["one"] = 3
    values["two"] = 7
    var native_values = values.copy()
    assert_equal(raise_on_err(attempt(total, **values^)), total(**native_values^))
    assert_equal(raise_on_err(forward(one=3, two=7)), 30)
    assert_equal(raise_on_err(forward()), 0)
    assert_equal(raise_on_err(attempt(total, **StringDict[Int]())), 0)

    var calls = 0
    def stop(var **values: Int) raises StopIteration {mut calls} -> Int:
        calls += 1
        raise StopIteration()
    var stopped: Result[Int, StopIteration] = attempt(stop, code=7)
    assert_equal(stopped.is_err(), True)
    assert_equal(calls, 1)
    def no_value(var **values: Int) {mut calls} -> None:
        calls += len(values)
    var empty = attempt(no_value, first=1, second=2)
    assert_equal(empty.is_ok(), True)
    assert_equal(calls, 3)
    assert_equal(raise_on_err(attempt(defaults, 3, one=4)), defaults(3, one=4))


def defaults(first: Int = 3, /, var **values: Int) -> Int:
    return first + total(**values^)
