from fp.functions import pipeline
from fp.algebra import NonEmptyListFamily, ListFamily
from fp.data import NonEmptyList
from std.testing import assert_equal

def keep(x: Int) -> Bool: return x > 2

def add(var x: Int) -> Int: return x+1

def choose(var x: Int) -> Optional[Int]: return Optional(x) if x > 2 else Optional[Int]()

def main() raises:
    var a = pipeline[NonEmptyListFamily](NonEmptyList(1, List[Int]([2,3]))).filter(keep).map(add).get()
    assert_equal(a, List[Int]([4]))
    var b = pipeline[NonEmptyListFamily](NonEmptyList(1, List[Int]([2,3]))).filter_not(keep).map(add).get()
    assert_equal(b, List[Int]([2,3]))
    var c = pipeline[NonEmptyListFamily](NonEmptyList(1, List[Int]([2,3]))).filter_map(choose).map(add).get()
    assert_equal(c, List[Int]([4]))
    var d = pipeline[NonEmptyListFamily](NonEmptyList(Optional(1), List[Optional[Int]]())).compact().map(add).get()
    assert_equal(d, List[Int]([2]))
