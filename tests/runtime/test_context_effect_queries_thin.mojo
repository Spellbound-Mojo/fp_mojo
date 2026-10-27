"""Stored native pointers retain consumed operand and result calling conventions."""
from fp.functions import pipeline
from fp.algebra import OptionalFamily, StringMonoid
from std.testing import assert_equal

def choose(value: Int) -> Optional[Bool]: return Optional(value == 2)
def never_choose(value: Int) raises Never -> Optional[Bool]: return Optional(value == 2)
def fail_choose(value: Int) raises Int -> Optional[Bool]: raise value
def project(var value: Int) -> Optional[Optional[Int]]: return Optional(Optional(value))
def string_project(var value: String) -> Optional[Optional[Int]]: return Optional(Optional(value.byte_length()))
def optional_project(var value: Optional[Int]) -> Optional[Optional[Int]]: return Optional(value^)
def never_project(var value: Int) raises Never -> Optional[Optional[Int]]: return Optional(Optional(value))
def fail_project(var value: Int) raises Int -> Optional[Optional[Int]]: raise value
def text(var value: Int) -> Optional[String]: return Optional(String(value))
def keep_text(var value: String) -> Optional[String]: return Optional(value^)
def add(var a: Int, var b: Int) -> Optional[Int]: return Optional(a + b)
def never_add(var a: Int, var b: Int) raises Never -> Optional[Int]: return Optional(a + b)
def fail_add(var a: Int, var b: Int) raises Int -> Optional[Int]: raise a + b
def append(var a: String, var b: Int) -> Optional[String]: return Optional(a + String(b))
def length(var a: Int, var b: String) -> Optional[Int]: return Optional(a + b.byte_length())
def join(var a: String, var b: String) -> Optional[String]: return Optional(a + b)
def alternatives(var a: Int, var b: Int) -> List[Int]: return List[Int]([a + b, a - b])

def nonraising() -> Int:
    var predicate: def(Int) raises Never thin -> Optional[Bool] = never_choose
    var mapper: def(var Int) raises Never thin -> Optional[Optional[Int]] = never_project
    var step: def(var Int, var Int) raises Never thin -> Optional[Int] = never_add
    _ = pipeline(List[Int]([1,2])).raising[Int]().any_effect(predicate).get()
    _ = pipeline(List[Int]([1,2])).raising[Int]().find_map_effect(mapper).get()
    return pipeline(List[Int]([1,2])).raising[Int]().fold_effect(10).run(step).get().value()

def main() raises:
    assert_equal(nonraising(), 13)
    var predicate: def(Int) thin -> Optional[Bool] = choose
    assert_equal(pipeline(List[Int]([1,2])).all_effect(predicate).get().value(), False)
    assert_equal(pipeline(List[Int]([1,2])).find_effect(predicate).get().value().value(), 2)
    var mapper: def(var Int) thin -> Optional[Optional[Int]] = project
    assert_equal(pipeline(List[Int]([1,2])).find_map_effect(mapper).get().value().value(), 1)
    var strings: def(var String) thin -> Optional[Optional[Int]] = string_project
    assert_equal(pipeline(List[String](["abc"])).find_map_effect(strings).get().value().value(), 3)
    # Optional[Int] is a nontrivial RegisterPassable consumed argument.
    var optionals: def(var Optional[Int]) thin -> Optional[Optional[Int]] = optional_project
    assert_equal(pipeline(List[Optional[Int]]([Optional(7)])).find_map_effect(optionals).get().value().value(), 7)
    var stringer: def(var Int) thin -> Optional[String] = text
    assert_equal(pipeline(List[Int]([1,2])).fold_map_effect[OptionalFamily,StringMonoid](stringer).get().value(), "12")
    var keeper: def(var String) thin -> Optional[String] = keep_text
    assert_equal(pipeline(List[String](["a","b"])).fold_map_effect[OptionalFamily,StringMonoid](keeper).get().value(), "ab")
    var step: def(var Int,var Int) thin -> Optional[Int] = add
    assert_equal(pipeline(List[Int]([1,2])).fold_effect(10).run(step).get().value(), 13)
    var appender: def(var String,var Int) thin -> Optional[String] = append
    assert_equal(pipeline(List[Int]([1,2])).fold_effect(String("a")).run(appender).get().value(), "a12")
    var measure: def(var Int,var String) thin -> Optional[Int] = length
    assert_equal(pipeline(List[String](["a","bc"])).fold_effect(10).run(measure).get().value(), 13)
    var joiner: def(var String,var String) thin -> Optional[String] = join
    assert_equal(pipeline(List[String](["a","b"])).fold_effect(String()).run(joiner).get().value(), "ab")
    var branch: def(var Int,var Int) thin -> List[Int] = alternatives
    assert_equal(pipeline(List[Int]([1,2])).fold_effect(0).run(branch).get(), List[Int]([3,-1,1,-3]))
    var bad_predicate: def(Int) raises Int thin -> Optional[Bool] = fail_choose
    var bad_mapper: def(var Int) raises Int thin -> Optional[Optional[Int]] = fail_project
    var bad_step: def(var Int,var Int) raises Int thin -> Optional[Int] = fail_add
    var code = 0
    try: _ = pipeline(List[Int]([3])).raising[Int]().any_effect(bad_predicate).get()
    except error: code = error
    assert_equal(code, 3)
    try: _ = pipeline(List[Int]([4])).raising[Int]().find_map_effect(bad_mapper).get()
    except error: code = error
    assert_equal(code, 4)
    try: _ = pipeline(List[Int]([5])).raising[Int]().fold_effect(10).run(bad_step).get()
    except error: code = error
    assert_equal(code, 15)
