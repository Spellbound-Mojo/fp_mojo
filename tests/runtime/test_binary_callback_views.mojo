"""Named standard binary wrappers reuse shared calls without changing custom receivers."""
from fp.functions import partial, flow, flip
from fp.iteration import iterated, zip_with, map_with_index
from fp.callables import Binary, MutableBinary
from std.testing import assert_equal
from std.iter import Iterator
from fp.iteration import ZipWithIterator


def combine(bias: Int, first: Int, second: Int) -> Int: return bias + first * 10 + second
def add(var first: Int, var second: Int) -> Int: return first + second
def twice(var value: Int) -> Int: return value * 2

@fieldwise_init
struct Offset(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    var value: Int
    def call(self, var first: Int, var second: Int) -> Int: return self.value + first + second


@fieldwise_init
struct Dual(Binary, MutableBinary, ImplicitlyCopyable):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    var offset: Int
    def call(self, var a: Int, var b: Int) -> Int: return 100 + self.offset + a + b
    def call_mut(mut self, var a: Int, var b: Int) -> Int: return 200 + self.offset + a + b

def generic[F: Binary, I: Iterator, J: Iterator](var callback: F, var left: I, var right: J) -> ZipWithIterator[F.First, F.Second, F.Out, I, J, F] where I.Element == F.First and J.Element == F.Second and F.Error == Never:
    return zip_with[F=F](left^, right^, callback^)


def main() raises:
    var project = partial(combine, 100)
    assert_equal(iterated(zip_with(range(2), range(3,5), project)).collect_list(), [103,114])
    assert_equal(iterated(range(2)).zip_with(range(3,5), project).collect_list(), [103,114])
    assert_equal(iterated(map_with_index(range(3), project, start=2)).collect_list(), [120,131,142])
    assert_equal(iterated(range(3)).map_with_index(project, start=2).collect_list(), [120,131,142])
    var composed = flow(add, twice)
    assert_equal(iterated(range(2)).zip_with(range(3,5), composed).collect_list(), [6,10])
    assert_equal(iterated(range(3)).map_with_index(composed).collect_list(), [0,4,8])
    var flipped = flip(project.copy())
    assert_equal(iterated(range(2)).zip_with(range(3,5), flipped).collect_list(), [130,141])
    assert_equal(iterated(range(3)).map_with_index(flipped, start=2).collect_list(), [102,113,124])
    assert_equal(iterated(range(2)).zip_with(range(3,5), project^).collect_list(), [103,114])
    var native_flip = flip(add)
    assert_equal(iterated(range(2)).zip_with(range(3,5), native_flip).collect_list(), [3,5])
    assert_equal(iterated(range(3)).map_with_index(native_flip).collect_list(), [0,2,4])
    assert_equal(iterated(range(2)).zip_with(range(3,5), Offset(5)).collect_list(), [8,10])
    assert_equal(iterated(generic(Offset(5), range(2), range(3,5))).collect_list(), [8,10])
    var dual = Dual(0)
    assert_equal(iterated(range(2)).zip_with(range(2), dual).collect_list(), [200,202])
    assert_equal(iterated(range(2)).map_with_index(dual).collect_list(), [200,202])
