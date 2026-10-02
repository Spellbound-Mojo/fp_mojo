"""Stored Result failures stay distinct from the native channel selected by attempt."""
from fp.data import Result, Ok, Err, attempt, raise_on_err
from std.testing import assert_equal

@fieldwise_init
struct InnerFailure(Movable):
    var code: Int

@fieldwise_init
struct OuterFailure(Movable):
    var code: Int

@fieldwise_init
struct Token(Movable):
    var value: Int

comptime Item = Result[Token, InnerFailure]

def stored(var value: Token) -> Item:
    if value.value < 0: return Item(Err(InnerFailure(17)))
    return Item(Ok(value^))

def fallible(var value: Token, mode: Int) raises OuterFailure -> Item:
    if mode: raise OuterFailure(42)
    return stored(value^)

def defaults(first: Int, second: Int = 3) -> Int:
    return first * 10 + second

def main() raises:
    var ordinary: Result[Item, Never] = attempt(stored, Token(-1))
    assert_equal(ordinary.is_ok(), True)
    var inner = raise_on_err(ordinary^)
    assert_equal(inner.is_err(), True)
    var inner_code = 0
    try: _ = raise_on_err(inner^)
    except error: inner_code = error.code
    assert_equal(inner_code, 17)
    for mode in range(2):
        for value in range(-1, 2):
            var captured: Result[Item, OuterFailure] = attempt(fallible, Token(value), mode)
            assert_equal(captured.is_err(), Bool(mode))
            var outer_code = 0
            var selected: Optional[Item] = None
            try: selected = Optional(raise_on_err(captured^))
            except error: outer_code = error.code
            assert_equal(outer_code, 42 if mode else 0)
            if not mode:
                var item = selected.take()
                assert_equal(item.is_err(), value < 0)
                var observed = 0
                var code = 0
                try:
                    var token = raise_on_err(item^)
                    observed = token.value
                except error: code = error.code
                assert_equal(code, 17 if value < 0 else 0)
                if value >= 0: assert_equal(observed, value)
    assert_equal(raise_on_err(attempt(defaults, 2, 4)), defaults(2, 4))
    var calls = 0
    def stop(value: Int) raises StopIteration {mut calls} -> Int:
        calls += 1
        raise StopIteration()
    var stopped: Result[Int, StopIteration] = attempt(stop, 7)
    assert_equal(stopped.is_err(), True)
    assert_equal(calls, 1)
    def nothing(value: Int) -> NoneType: return None
    var empty: Result[NoneType, Never] = attempt(nothing, 3)
    assert_equal(empty.is_ok(), True)
    def no_value(value: Int) {mut calls} -> None:
        calls += value
    var inferred_void = attempt(no_value, 3)
    assert_equal(inferred_void.is_ok(), True)
    assert_equal(calls, 4)
