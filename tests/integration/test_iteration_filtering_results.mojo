"""Captured Optional/Result callbacks preserve errors as elements and compose lazily."""
from fp.iteration import filter, filter_map, flat_map, collect_list
from fp.data import Result, Ok, Err, collect_results
from std.iter import iter
from std.itertools import take
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Token(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct FilteringFailure(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

comptime Item = Result[Token, FilteringFailure]

def optional_results(stop: Bool, tokens: ArcPointer[Int], errors: ArcPointer[Int]) raises:
    var calls = 0
    def callback(var value: Int) {mut calls, tokens, errors} -> Optional[Item]:
        calls += 1
        if value == 0: return None
        if value == 2: return Optional(Item(Err(FilteringFailure(42, errors))))
        return Optional(Item(Ok(Token(value * 10, tokens))))
    if stop:
        var result = collect_results(filter_map(callback, iter(range(4))))
        assert_equal(result.is_err(), True)
        assert_equal(calls, 3)
        assert_equal(tokens[], 1)
        var caught = False
        try: _ = result^.raise_on_err()
        except error:
            caught = True
            assert_equal(error.code, 42)
        assert_equal(caught, True)
    else:
        var values = collect_list(filter_map(callback, iter(range(4))))
        assert_equal(len(values), 3)
        assert_equal(values[0].is_err(), False)
        assert_equal(values[1].is_err(), True)
        assert_equal(values[2].is_err(), False)
        assert_equal(calls, 4)
        assert_equal(tokens[], 0)
        assert_equal(errors[], 0)
        _ = values^

def flat_results(stop: Bool, tokens: ArcPointer[Int], errors: ArcPointer[Int]) raises:
    var calls = 0
    def callback(var value: Int) {mut calls, tokens, errors} -> List[Item]:
        calls += 1
        var result = List[Item]()
        if value:
            result.append(Item(Ok(Token(value * 10, tokens))))
            if value == 1: result.append(Item(Err(FilteringFailure(42, errors))))
        return result^
    if stop:
        var result = collect_results(flat_map(callback, iter(range(3))))
        assert_equal(result.is_err(), True)
        assert_equal(calls, 2)
        assert_equal(tokens[], 1)
        var caught = False
        try: _ = result^.raise_on_err()
        except error:
            caught = True
            assert_equal(error.code, 42)
        assert_equal(caught, True)
    else:
        var values = collect_list(flat_map(callback, iter(range(3))))
        assert_equal(len(values), 3)
        assert_equal(values[0].is_err(), False)
        assert_equal(values[1].is_err(), True)
        assert_equal(values[2].is_err(), False)
        assert_equal(calls, 3)
        assert_equal(tokens[], 0)
        assert_equal(errors[], 0)
        _ = values^

def main() raises:
    for mode in range(2):
        for stop in range(2):
            var tokens = ArcPointer(0)
            var errors = ArcPointer(0)
            if mode: flat_results(Bool(stop), tokens, errors)
            else: optional_results(Bool(stop), tokens, errors)
            assert_equal(tokens[], 1 if stop else 2)
            assert_equal(errors[], 1)
    var predicates = 0
    var optionals = 0
    var expansions = 0
    def positive(value: Int) {mut predicates} -> Bool:
        predicates += 1
        return value > 0
    def twice_even(var value: Int) {mut optionals} -> Optional[Int]:
        optionals += 1
        return Optional(value * 2) if value % 2 == 0 else None
    def pair(var value: Int) {mut expansions} -> List[Int]:
        expansions += 1
        return [value, value + 1]
    var selected = filter(positive, iter(range(6)))
    var mapped = filter_map(twice_even, selected^)
    var flattened = flat_map(pair, mapped^)
    assert_equal(predicates, 0)
    assert_equal(optionals, 0)
    assert_equal(expansions, 0)
    assert_equal(collect_list(take(flattened^, 3)), [4, 5, 8])
    assert_equal(predicates, 5)
    assert_equal(optionals, 4)
    assert_equal(expansions, 2)
