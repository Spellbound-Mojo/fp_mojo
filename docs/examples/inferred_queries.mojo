"""Search and test with native effects, inferring their target families."""
from fp.data import Result, Ok, Err
from fp.functions import pipeline, kleisli
from fp.algebra import ResultFamily
from std.testing import assert_equal

def enabled(value: Int) -> Result[Bool, String]:
    if value < 0: return Err(String("invalid identifier"))
    return Ok(value % 2 == 0)

def label(var value: Int) -> Result[Optional[String], String]:
    if value < 0: return Err(String("invalid identifier"))
    return Ok(Optional("item-" + String(value)) if value >= 3 else Optional[String]())

def main() raises:
    var any_enabled = pipeline(List[Int]([1, 2, 3])).any_effect(enabled).get_or(False)
    var all_enabled = pipeline(List[Int]([1, 2, 3])).all_effect(enabled).get_or(False)
    assert_equal(any_enabled, True)
    assert_equal(all_enabled, False)
    print("any:", any_enabled)
    print("all:", all_enabled)
    var first = pipeline(range(1, 5)).find_effect(enabled).raise_on_err()
    assert_equal(first.value(), 2)
    print("first:", first.value())
    var naming = kleisli[ResultFamily[String]](label)
    var named = pipeline(range(1, 5)).find_map_effect(naming).raise_on_err()
    assert_equal(pipeline(List[Int]([4])).find_map_effect(naming).raise_on_err().value(), "item-4")
    assert_equal(named.value(), "item-3")
    print("label:", named.value())
    var failure = pipeline(List[Int]([-1, 2])).any_effect(enabled).swap().get_or("")
    assert_equal(failure, "invalid identifier")
