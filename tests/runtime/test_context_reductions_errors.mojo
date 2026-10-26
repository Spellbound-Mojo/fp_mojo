"""Monoid identity, combination and callback failures retain their exact types."""
from fp.functions import pipeline
from fp.algebra import Monoid
from std.testing import assert_equal
from algebra_support.iterators import Counted

struct CheckedSum[fail_start: Bool](Monoid):
    comptime Value = Int
    comptime Error = Int
    @staticmethod
    def empty() raises Int -> Int:
        if Self.fail_start: raise 99
        return 0
    @staticmethod
    def combine(var left: Int,var right: Int) raises Int -> Int:
        if right == 2: raise 22
        return left + right

def main() raises:
    var code=0
    var pulls=0
    try: _ = pipeline(Counted(Pointer(to=pulls),0,4)).combine_all[CheckedSum[True]]().get()
    except error: code=error
    assert_equal(code,99); assert_equal(pulls,0)
    try: _ = pipeline(Counted(Pointer(to=pulls),0,4)).combine_all[CheckedSum[False]]().get()
    except error: code=error
    assert_equal(code,22); assert_equal(pulls,2)
    def checked(var value: Int) raises Int -> Int:
        if value == 1: raise 11
        return value
    pulls=0
    try: _ = pipeline(Counted(Pointer(to=pulls),0,4)).raising[Int]().fold_map[CheckedSum[False]](checked).get()
    except error: code=error
    assert_equal(code,11); assert_equal(pulls,1)
    def stop(var value: Int) raises StopIteration -> Optional[Int]: raise StopIteration()
    var caught=False
    try: _ = pipeline(range(3)).raising[StopIteration]().find_map(stop).get()
    except StopIteration: caught=True
    assert_equal(caught,True)
