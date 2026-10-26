"""Ordered reduction and numeric inference preserve native result types."""
from fp.functions import pipeline
from fp.algebra import StringMonoid
from std.testing import assert_equal
from algebra_support.iterators import Counted

def main() raises:
    assert_equal(pipeline(List[Int]([1,2,3])).sum().get(), 6)
    assert_equal(pipeline(List[Int]()).sum().get(), 0)
    def twice(var x: Int) -> Int: return x*2
    assert_equal(pipeline(range(4)).sum_by(twice).get(), 12)
    def present(var x: Int) -> Optional[String]: return Optional(String(x)) if x > 1 else Optional[String]()
    assert_equal(pipeline(range(5)).find_map(present).get().value(), "2")
    var pulls = 0
    assert_equal(pipeline(Counted(Pointer(to=pulls),0,5)).find_map(present).get().value(), "2")
    assert_equal(pulls,2)
    assert_equal(Bool(pipeline(List[Int]()).find_map(present).get()),False)
    def show(var x: Int) -> String: return String(x)
    assert_equal(pipeline(range(3)).fold_map[StringMonoid](show).get(), "012")
    assert_equal(pipeline(List[String](["a","b"])).combine_all[StringMonoid]().get(), "ab")
    assert_equal(pipeline(List[String]()).combine_all[StringMonoid]().get(), "")
    def key(x: String) -> Int: return x.byte_length()
    assert_equal(pipeline(List[String](["a","bbbb","cc"])).max_by(key).get().value(), "bbbb")
    assert_equal(pipeline(List[String](["a","bbbb","cc"])).min_by(key).get().value(), "a")
    assert_equal(Bool(pipeline(List[String]()).min_by(key).get()),False)
    assert_equal(pipeline(List[String](["aa","bb"])).max_by(key).get().value(),"aa")
    comptime V = SIMD[DType.float32,4]
    assert_equal(pipeline(List[V]([V(1),V(2)])).sum().get(), V(3))
    def vector(var x: Int) -> V: return V(Float32(x))
    assert_equal(pipeline(range(3)).sum_by(vector).get(), V(3))
    assert_equal(pipeline(List[V]()).sum().get(), V(0))
    assert_equal(pipeline(List[V]([V(1),V(2)])).sum[DType.float32,4]().get(),V(3))
    assert_equal(pipeline(range(3)).sum_by[DType.float32,4](vector).get(),V(3))
    assert_equal(pipeline(range(4)).sum().map(twice).get(),12)
