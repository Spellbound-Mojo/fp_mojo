"""Shared projections preserve free and fluent alignment, including explicit bindings."""
from fp.functions import partial, as_unary, flow, kleisli
from fp.iteration import align_with, iterated
from fp.data import Ior, Left, Right, Both
from fp.algebra import OptionalFamily
from std.testing import assert_equal

def total(value: Ior[Int, Int]) -> Int:
    if value.isa[Left[Int]](): return value[Left[Int]].value
    if value.isa[Right[Int]](): return value[Right[Int]].value
    return value[Both[Int, Int]].left + value[Both[Int, Int]].right
def biased(bias: Int, value: Ior[Int, Int]) -> Int: return bias + total(value)
def twice(var value: Int) -> Int: return value * 2
def present(var value: Ior[Int, Int]) -> Optional[Int]: return Optional(total(value))
def main() raises:
    var project = partial(biased, 10)
    assert_equal(iterated(align_with(range(2), range(3), project)).collect_list(), [10,12,12])
    assert_equal(iterated(range(3)).align_with(range(1), project).collect_list(), [10,11,12])
    assert_equal(iterated(align_with[Int, Int](range(1), range(3), project)).collect_list(), [10,11,12])
    assert_equal(iterated(range(3)).align_with[A=Int, B=Int](range(1), project).collect_list(), [10,11,12])
    assert_equal(iterated(range(2)).align_with(range(3), partial(biased, 10)).collect_list(), [10,12,12])
    var native = as_unary(total)
    assert_equal(iterated(range(2)).align_with(range(3), native).collect_list(), [0,2,2])
    assert_equal(iterated(range(2)).align_with(range(3), native).collect_list(), [0,2,2])
    var composed = flow(total, twice)
    assert_equal(iterated(range(2)).align_with(range(3), composed).collect_list(), [0,4,4])
    assert_equal(iterated(range(2)).align_with(range(3), composed).collect_list(), [0,4,4])
    assert_equal(iterated(range(2)).align_with(range(3), project^).collect_list(), [10,12,12])
    var effect = kleisli[OptionalFamily](present)
    var first = iterated(align_with(range(1), range(3), effect)).collect_list()
    var again = iterated(range(3)).align_with(range(1), effect).collect_list()
    comptime assert type_of(first) == List[Optional[Int]]
    assert_equal(first, again)
    assert_equal(first[2].value(), 2)
