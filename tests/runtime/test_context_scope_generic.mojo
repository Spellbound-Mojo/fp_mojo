from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.testing import assert_equal

@fieldwise_init
struct ContextScopeGenericFault(Movable):
    var code: Int

def validate[P: def(Int) -> Bool, F: def(Int) -> String](predicate: P, factory: F) -> Result[Int, String]:
    return pipeline(Result[Int,String](Ok(3))).raising[ContextScopeGenericFault]().ensure(predicate, factory).get()

def transform[F: def(var String) -> Int](function: F) -> Result[Int, Int]:
    return pipeline(Result[Int,String](Err(String("bad")))).raising[ContextScopeGenericFault]().map_err(function).get()

def follow[F: def() -> Result[Int,String]](function: F) -> Result[Int,String]:
    return pipeline(Result[Int,String](Ok(1))).raising[ContextScopeGenericFault]().followed_by(function).get()

def observe[F: def(String)](function: F) -> Result[Int,String]:
    return pipeline(Result[Int,String](Err(String("bad")))).raising[ContextScopeGenericFault]().tap_err(function).get()

def main() raises:
    var count = 0
    var label = String("bad")
    def predicate(value: Int) {mut count} -> Bool:
        count += 1
        return False
    def make_error(value: Int) {label} -> String:
        return label
    def length(var value: String) {mut count} -> Int:
        count += 1
        return value.byte_length()
    def next() {mut count} -> Result[Int,String]:
        count += 1
        return Ok(count)
    def seen(value: String) {mut count}:
        count += value.byte_length()
    assert_equal(validate(predicate,make_error)._err().value,"bad")
    assert_equal(transform(length)._err().value,3)
    assert_equal(follow(next)._ok().value,3)
    assert_equal(observe(seen)._err().value,"bad")
    assert_equal(count,6)
