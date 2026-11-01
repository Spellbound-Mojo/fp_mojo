"""One bound native predicate or observer is reusable across selected operations."""
from fp.functions import pipeline, partial
from fp.data import ok, err
from fp.algebra import IdentityFamily
from std.testing import assert_equal, assert_true

def above(limit: Int, value: Int) -> Bool: return value > limit
def show(var prefix: String, value: Int) -> String: return prefix + String(value)
def choose(limit: Int, value: Int) -> Optional[Bool]: return Optional(value > limit)
def failing(offset: Int, value: Int) raises Int -> Bool: raise offset + value

def main() raises:
    var predicate = partial(above, 2)
    assert_equal(pipeline[List[Int]]([1, 2, 3, 4]).filter(predicate).get(), [3, 4])
    assert_equal(pipeline[List[Int]]([1, 2, 3]).filter_not(predicate).get(), [1, 2])
    assert_equal(pipeline[List[Int]]([1, 2, 3]).filter(partial(above, 1)).get(), [2, 3])
    var label = partial(show, String("value: "))
    assert_equal(pipeline(ok[Int](4)).fold(label, label), "value: 4")
    assert_equal(pipeline(err[Int](5)).fold(label, label), "value: 5")
    assert_equal(pipeline[List[Int]]([1, 2]).pair_with(label).get()[1][1], "value: 2")
    assert_equal(pipeline[List[Int]]([1, 2]).map(partial(above, 1)).get(), [False, True])
    assert_equal(pipeline[List[Int]]([]).filter(predicate).get(), List[Int]())
    assert_equal(pipeline(ok[String](3)).ensure(predicate, label).get_or(0), 3)
    assert_equal(pipeline(ok[String](1)).ensure(predicate, label).swap().get_or(""), "value: 1")
    def native_label(value: Int) -> String: return String(value)
    assert_equal(pipeline(err[Int](6)).fold(label, native_label), "6")
    assert_equal(pipeline(ok[Int](7)).fold(native_label, label), "7")
    assert_equal(pipeline[IdentityFamily](err[String](4)).tap_err(label).get()._err().value, 4)
    var decision = partial(choose, 1)
    assert_equal(pipeline[List[Int]]([1, 2, 3]).filter_effect(decision).get().value(), [2, 3])
    assert_true(pipeline[List[Int]]([1, 2]).any_effect(decision).get_or(False))
    assert_equal(pipeline[List[Int]]([1, 2]).find_effect(decision).get().value().value(), 2)
    var raising = partial(failing, 10)
    var caught = False
    try: _ = pipeline[List[Int]]([1]).raising[String]().filter(raising).get()
    except error:
        comptime assert type_of(error) == Int
        assert_equal(error, 11)
        caught = True
    assert_true(caught)
    assert_equal(pipeline[List[Int]]([2, 3]).filter[C=type_of(predicate)](predicate^).get(), [3])
