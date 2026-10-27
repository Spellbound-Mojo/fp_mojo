"""Combine existing effects with inferred targets and no identity callback."""
from fp.functions import pipeline
from fp.algebra import StringMonoid, ListMonoid, OptionalFamily
from fp.data import Result, Ok, Err
from std.collections import Array, Deque
from std.iter import Iterator, IterableOwned
from std.testing import assert_equal

@fieldwise_init
struct TextEffects[o: MutOrigin](Iterator, IterableOwned):
    comptime Element = Optional[String]
    comptime IteratorOwnedType = Self
    var pulls: Pointer[Int, origin=Self.o]
    var index: Int
    var count: Int
    var absent: Int
    def __iter__(var self) -> Self:
        self.index = 0
        return self^
    def __next__(mut self) raises StopIteration -> Self.Element:
        self.pulls[] += 1
        if self.index == self.count: raise StopIteration()
        self.index += 1
        return Optional(String(self.index)) if self.index != self.absent else Optional[String]()

def joined[T: Movable & Deinitable](var groups: List[Optional[List[T]]]) -> Optional[List[T]]:
    return pipeline(groups^).combine_all_effect[ListMonoid[T]]().get()

def origins(owner: List[Int]) raises:
    comptime View = type_of(Span(owner))
    var items = List[View]([Span(owner)])
    var groups = List[Optional[List[View]]]()
    groups.append(Optional(items^))
    var output = joined(groups^)
    assert_equal(output.value()[0].unsafe_ptr() == Span(owner).unsafe_ptr(), True)

def main() raises:
    var optional: List[Optional[String]] = [Optional(String("a")), Optional(String("b"))]
    assert_equal(pipeline(optional^).combine_all_effect[StringMonoid]().get_or(""), "ab")
    assert_equal(pipeline(List[Optional[String]]()).combine_all_effect[StringMonoid]().get_or("fallback"), "")
    assert_equal(pipeline(List[Optional[String]]()).combine_all_effect[OptionalFamily, StringMonoid]().get_or("fallback"), "")
    assert_equal(pipeline(List[Optional[String]]()).combine_all_effect[J=OptionalFamily, M=StringMonoid]().get_or("fallback"), "")
    assert_equal(pipeline(List[Optional[String]]()).combine_all_effect[M=StringMonoid]().get_or("fallback"), "")
    var result = List[Result[String, Int]]()
    result.append(Ok(String("a"))); result.append(Ok(String("b")))
    assert_equal(pipeline(result^).combine_all_effect[StringMonoid]().get_or(""), "ab")
    assert_equal(pipeline(List[Result[String, Int]]()).combine_all_effect[StringMonoid]().get_or("fallback"), "")
    var failed = List[Result[String, Int]]()
    failed.append(Ok(String("a"))); failed.append(Err(7)); failed.append(Err(8))
    assert_equal(pipeline(failed^).combine_all_effect[StringMonoid]().swap().get_or(0), 7)
    var branches: List[List[String]] = [["a", "A"], ["b", "B"]]
    assert_equal(pipeline(branches^).combine_all_effect[StringMonoid]().get(), List[String](["ab", "aB", "Ab", "AB"]))
    assert_equal(pipeline(List[List[String]]()).combine_all_effect[StringMonoid]().get(), List[String]([""]))
    var array: Array[Optional[String], 2] = [Optional(String("a")), Optional(String("b"))]
    assert_equal(pipeline(array^).combine_all_effect[StringMonoid]().get_or(""), "ab")
    var deque = Deque[Optional[String]]()
    deque.append(Optional(String("a"))); deque.append(Optional(String("b")))
    assert_equal(pipeline(deque^).combine_all_effect[StringMonoid]().get_or(""), "ab")
    var pulls = 0
    assert_equal(pipeline(TextEffects(Pointer(to=pulls), 0, 4, 2)).combine_all_effect[StringMonoid]().get_or("absent"), "absent")
    assert_equal(pulls, 2)
    pulls = 0
    var cursor = TextEffects(Pointer(to=pulls), 0, 3, 0)
    _ = cursor.__next__()
    assert_equal(pipeline(cursor^).combine_all_effect[StringMonoid]().get_or(""), "23")
    assert_equal(pulls, 4)
    origins(List[Int]([3, 4]))
