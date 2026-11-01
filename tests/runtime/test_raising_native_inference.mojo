"""Raising plain functions and closures need no X= hint; their errors propagate with their exact types."""
from std.testing import assert_equal
from fp.iteration import (traverse, flat_traverse, traverse_filter, traverse_tap, traverse_void, filter_effect,
                          any_effect, all_effect, find_effect, find_map_effect, fold_effect, fold_map_effect, iterated)
from fp.functions import pipeline
from fp.algebra import StringMonoid


def half(var v: Int) raises String -> Optional[Int]:
    if v < 0: raise String("half")
    return v
def pair(var v: Int) raises String -> Optional[List[Int]]:
    if v < 0: raise String("pair")
    return List[Int]([v])
def keep(var v: Int) raises String -> Optional[Optional[Int]]:
    if v < 0: raise String("keep")
    return Optional[Optional[Int]](Optional[Int](v))
def observe(v: Int) raises String -> Optional[Int]:
    if v < 0: raise String("observe")
    return v
def even(v: Int) raises String -> Optional[Bool]:
    if v < 0: raise String("even")
    return v % 2 == 0
def add(var total: Int, var v: Int) raises String -> Optional[Int]:
    if v < 0: raise String("add")
    return total + v
def text(var v: Int) raises String -> Optional[String]:
    if v < 0: raise String("text")
    return String(v)


def raised[F: def() raises String](f: F) -> String:
    try:
        f()
    except error:
        comptime assert type_of(error) == String
        return error
    return String("none")


def plain_functions() raises:
    def a() raises String: _ = traverse(List[Int]([-1]), half)
    def b() raises String: _ = flat_traverse(List[Int]([-1]), pair)
    def c() raises String: _ = traverse_filter(List[Int]([-1]), keep)
    def d() raises String: _ = traverse_tap(List[Int]([-1]), observe)
    def e() raises String: _ = traverse_void(List[Int]([-1]), half)
    def f() raises String: _ = filter_effect(List[Int]([-1]), even)
    def g() raises String: _ = any_effect(List[Int]([-1]), even)
    def h() raises String: _ = find_effect(List[Int]([-1]), even)
    def i() raises String: _ = find_map_effect(List[Int]([-1]), keep)
    def j() raises String: _ = fold_effect(List[Int]([-1]), 0, add)
    def k() raises String: _ = fold_map_effect[StringMonoid](List[Int]([-1]), text)
    assert_equal(raised(a), "half")
    assert_equal(raised(b), "pair")
    assert_equal(raised(c), "keep")
    assert_equal(raised(d), "observe")
    assert_equal(raised(e), "half")
    assert_equal(raised(f), "even")
    assert_equal(raised(g), "even")
    assert_equal(raised(h), "even")
    assert_equal(raised(i), "keep")
    assert_equal(raised(j), "add")
    assert_equal(raised(k), "text")


def fluent_surfaces() raises:
    def a() raises String: _ = iterated(List[Int]([-1])).traverse(half)
    def b() raises String: _ = iterated(List[Int]([-1])).traverse_void(half)
    def c() raises String: _ = iterated(List[Int]([-1])).all_effect(even)
    def d() raises String: _ = pipeline(List[Int]([-1])).traverse_void(half).get()
    def e() raises String: _ = pipeline(List[Int]([-1])).find_effect(even).get()
    assert_equal(raised(a), "half")
    assert_equal(raised(b), "half")
    assert_equal(raised(c), "even")
    assert_equal(raised(d), "half")
    assert_equal(raised(e), "even")


def closures() raises:
    var limit = 0
    def check(v: Int) raises String {limit} -> Optional[Bool]:
        if v < limit: raise String("closure")
        return True
    def a() raises String {check}: _ = traverse_tap(List[Int]([-1]), check)
    def b() raises String {check}: _ = all_effect(List[Int]([-1]), check)
    def c() raises String {check}: _ = pipeline(List[Int]([-1])).raising[String]().filter_effect(check).get()
    assert_equal(raised(a), "closure")
    assert_equal(raised(b), "closure")
    assert_equal(raised(c), "closure")


def main() raises:
    plain_functions()
    fluent_surfaces()
    closures()
