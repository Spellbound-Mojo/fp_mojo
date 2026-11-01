"""Stored pointers retain their native argument, result and error conventions."""
from fp.functions import pipeline
from std.testing import assert_equal

def integer(var x: Int) -> Optional[Int]: return Optional(x)
def length(var x: String) -> Optional[Float64]: return Optional(Float64(x.byte_length()))
def optional(var x: Optional[Int]) -> Optional[Int]: return x^
def never(var x: Int) raises Never -> Optional[Int]: return Optional(x)
def fail(var x: Int) raises Int -> Optional[Int]: raise x

def nonraising() -> Int:
    var f: def(var Int) raises Never thin -> Optional[Int] = never
    return pipeline(List[Int]([1, 2])).raising[String]().sum_by_effect(f).get_or(0)

def main() raises:
    assert_equal(nonraising(), 3)
    var f: def(var Int) thin -> Optional[Int] = integer
    assert_equal(pipeline(List[Int]([1, 2])).sum_by_effect(f).get_or(0), 3)
    var g: def(var String) thin -> Optional[Float64] = length
    assert_equal(pipeline(List[String](["a", "bc"])).sum_by_effect(g).get_or(0), 3.0)
    var h: def(var Optional[Int]) thin -> Optional[Int] = optional
    assert_equal(pipeline(List[Optional[Int]]([Optional(2), Optional(3)])).sum_by_effect(h).get_or(0), 5)
    var failed: def(var Int) raises Int thin -> Optional[Int] = fail
    var code = 0
    try: _ = pipeline(List[Int]([7])).raising[Int]().sum_by_effect(failed).get()
    except error: code = error
    assert_equal(code, 7)
