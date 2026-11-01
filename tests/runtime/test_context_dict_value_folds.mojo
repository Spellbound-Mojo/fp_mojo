"""Folds over pipeline_values read the dictionary's values in insertion order."""
from fp.functions import pipeline_values
from fp.algebra import IntSumMonoid
from std.collections import StringDict
from std.testing import assert_equal
def twice(var value: Int) -> Int: return value * 2
def show(var value: Int) -> String: return String(value)
def add(var acc: Int, var value: Int) -> Int: return acc + value
def key(value: Int) -> Int: return value
def checked(var acc: Int, var value: Int) -> Optional[Int]:
    if value < 0: return None
    return acc + value
def main() raises:
    var prices = Dict[String, Int]()
    prices["a"] = 10
    prices["b"] = 20
    prices["c"] = 5
    assert_equal(pipeline_values(prices.copy()).sum().get(), 35)
    assert_equal(pipeline_values(prices.copy()).sum_by(twice).get(), 70)
    assert_equal(pipeline_values(prices.copy()).fold_map(show).get(), "10205")
    assert_equal(pipeline_values(prices.copy()).fold_map[IntSumMonoid](twice).get(), 70)
    assert_equal(pipeline_values(prices.copy()).fold_left(add, 1).get(), 36)
    assert_equal(pipeline_values(prices.copy()).max_by(key).get().value(), 20)
    assert_equal(pipeline_values(prices.copy()).fold_effect(0).run(checked).get().value(), 35)
    # Transformations still keep the dictionary and its keys.
    assert_equal(pipeline_values(prices.copy()).map(twice).get()["b"], 40)
    var named = StringDict[Int]()
    named["x"] = 3
    named["y"] = 4
    assert_equal(pipeline_values(named^).sum_by(twice).get(), 14)
