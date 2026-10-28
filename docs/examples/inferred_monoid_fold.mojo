"""Select how to combine values; infer the effect from the transformation."""
from fp.functions import pipeline, kleisli
from fp.algebra import StringMonoid, ResultFamily
from fp.data import Result, Ok, Err
from std.testing import assert_equal

def main() raises:
    var calls = 0
    def line(var word: String) {mut calls} -> Result[String, String]:
        calls += 1
        if not word: return Err(String("empty word"))
        return Ok(word + "!")
    var transform = kleisli[ResultFamily[String]](line)
    var text = pipeline(List[String](["hello", "world"])).fold_map_effect[StringMonoid](transform).get_or("")
    assert_equal(text, "hello!world!")
    print(text)
    calls = 0
    var reason = pipeline(List[String](["hello", "", "later"])).fold_map_effect[StringMonoid](transform).swap().get_or("")
    assert_equal(reason, "empty word"); assert_equal(calls, 2)
    print("error:", reason)
    print("transformed:", calls)
    assert_equal(pipeline(List[String]()).fold_map_effect[StringMonoid](transform).get_or("fallback"), "")
    assert_equal(calls, 2)
