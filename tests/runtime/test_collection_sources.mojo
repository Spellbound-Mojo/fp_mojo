"""Iteration over owned collections without iter(): consumed once, lazily."""
from fp.iteration import (map, filter, filter_map, flat_map, flatten, scan_left, collect_list, find, any, all,
    fold_left, fold_until, reduce, reduce_optional)
from fp.data import ControlFlow, Break, Continue
from fp.functions import partial
from std.collections import Set, Dict
from std.memory import ArcPointer
from std.iter import iter
from std.testing import assert_equal, assert_true, assert_false


@fieldwise_init
struct Token(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1


def twice(value: Int) -> Int:
    return value * 2


def positive(value: Int) -> Bool:
    return value > 0


def add(total: Int, value: Int) -> Int:
    return total + value


def odd(value: Int) -> Optional[Int]:
    return Optional(value) if value % 2 else Optional[Int]()


def pair(value: Int) -> List[Int]:
    return [value, value]


def size(var text: String) -> Int:
    return text.byte_length()


def until_big(total: Int, value: Int) -> ControlFlow[Int, Int]:
    if total + value > 4:
        return ControlFlow[Int, Int](Break(total + value))
    return ControlFlow[Int, Int](Continue(total + value))


def values() -> List[Int]:
    return [3, -1, 4]


def lists() raises:
    assert_equal(collect_list(map(values(), twice))[2], 8)
    assert_equal(len(collect_list(filter(values(), positive))), 2)
    assert_equal(len(collect_list(filter_map(values(), odd))), 2)
    assert_equal(len(collect_list(flat_map(values(), pair))), 6)
    assert_equal(collect_list(scan_left(values(), 0, add))[3], 6)
    assert_equal(collect_list(values())[1], -1)
    assert_equal(find(values(), positive).value(), 3)
    assert_true(any(values(), positive))
    assert_false(all(values(), positive))
    assert_equal(fold_left(values(), 0, add), 6)
    assert_equal(fold_left(values(), 0, partial(add)), 6)
    assert_equal(reduce(values(), add), 6)
    assert_equal(reduce_optional(values(), add).value(), 6)
    var stopped = fold_until(values(), 0, until_big)
    assert_true(stopped.isa[Break[Int]]())
    assert_equal(stopped[Break[Int]].value, 6)
    var nested: List[List[Int]] = [[1, 2], [3]]
    assert_equal(len(collect_list(flatten(nested^))), 3)
    var names: List[String] = ["ab", "cde"]
    assert_equal(fold_left(map(names^, size), 0, add), 5)


def other_sources() raises:
    assert_equal(fold_left(range(5), 0, add), 10)
    var s = Set[Int](1, 2, 3)
    assert_equal(fold_left(s^, 0, add), 6)
    var d = Dict[String, Int]()
    d["a"] = 1
    d["bc"] = 2
    assert_equal(fold_left(map(d^, size), 0, add), 3)
    # iter() still selects borrowed iteration; the collection stays usable.
    var kept: List[Int] = [1, 2]
    assert_equal(len(collect_list(iter(kept))), 2)
    assert_equal(len(kept), 2)


def laziness_and_ownership() raises:
    var calls = 0
    def counted(value: Int) {mut calls} -> Int:
        calls += 1
        return value
    var lazy = map(values(), counted)
    assert_equal(calls, 0)
    assert_equal(len(collect_list(lazy^)), 3)
    assert_equal(calls, 3)
    var drops = ArcPointer(0)
    var tokens = List[Token]()
    tokens.append(Token(1, drops))
    tokens.append(Token(2, drops))
    def unwrap(var token: Token) -> Int:
        return token.value
    assert_equal(fold_left(map(tokens^, unwrap), 0, add), 3)
    assert_equal(drops[], 2)


def main() raises:
    lists()
    other_sources()
    laziness_and_ownership()
    print("collection sources: lists, sets, dicts and ranges without iter()")
