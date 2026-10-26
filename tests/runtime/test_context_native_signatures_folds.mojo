"""Fold pointer admission preserves the existing callback-before-initial syntax."""
from fp.functions import pipeline
from fp.data import ControlFlow, Continue, Break
from std.testing import assert_equal

def add(var total: Int, var value: Int) -> Int: return total + value
def append(var total: String, var value: Int) -> String: return total + String(value)
def stop(var total: Int, var value: Int) -> ControlFlow[String, Int]:
    if value > 2: return Break(String(total))
    return Continue(total + value)
def stop_text(var total: String, var value: Int) -> ControlFlow[Int, String]:
    if value > 2: return Break(total.byte_length())
    return Continue(total + String(value))
def fail(var total: Int, var value: Int) raises String -> Int: raise String(total + value)
def never(var total: String, var value: Int) raises Never -> String: return total + String(value)

def main() raises:
    var integer: def(var Int, var Int) thin -> Int = add
    var memory: def(var String, var Int) thin -> String = append
    assert_equal(pipeline(List[Int]([1,2])).fold_left(integer, 0).get(), 3)
    assert_equal(pipeline(List[Int]([1,2])).fold_left(memory, String()).get(), "12")
    var breaking: def(var Int, var Int) thin -> ControlFlow[String, Int] = stop
    var breaking_text: def(var String, var Int) thin -> ControlFlow[Int, String] = stop_text
    var first = pipeline(List[Int]([1,2,3])).fold_until(breaking, 0).get()
    var second = pipeline(List[Int]([1,2,3])).fold_until(breaking_text, String()).get()
    assert_equal(first^.unwrap[Break[String]]().into_payload(), "3")
    assert_equal(second^.unwrap[Break[Int]]().into_payload(), 2)
    var raised: def(var Int, var Int) raises String thin -> Int = fail
    var message = String()
    try: _ = pipeline(List[Int]([1,2])).raising[String]().fold_left(raised, 10).get()
    except error: message = error^
    assert_equal(message, "11")
    var pure: def(var String, var Int) raises Never thin -> String = never
    assert_equal(pipeline(List[Int]([1,2])).raising[String]().fold_left(pure, String()).get(), "12")
