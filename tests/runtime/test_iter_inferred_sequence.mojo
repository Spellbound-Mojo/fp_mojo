from fp.iteration import iterated
from fp.data import Result, Ok, Err
from fp.algebra import ResultFamily, OptionalFamily, ValidationFamily, ListMonoid
from algebra_support.iterators import Counted
from algebra_support.box import Box, BoxMonad
from std.testing import assert_equal, assert_true, assert_false

def forwarded[T: Movable & Deinitable](var values: List[Optional[T]]) -> Optional[List[T]]:
    return iterated(values^).sequence()


def pure_discard() -> Optional[NoneType]:
    return iterated(List[Optional[Int]]()).sequence_void()


def stop(var value: Int) -> Optional[Int]:
    if value == 2: return None
    return Optional(value)


def main() raises:
    var values = List[Optional[Int]]([Optional(1), Optional(2)])
    var gathered = iterated(values^).sequence()
    assert_equal(gathered.value(), List[Int]([1,2]))
    var discarded = iterated(List[Optional[Int]]([Optional(1)])).sequence_void()
    assert_true(Bool(discarded))
    var empty = iterated(List[Optional[Int]]()).sequence()
    assert_equal(len(empty.value()), 0)
    var nested = List[Optional[List[Int]]]([Optional(List[Int]([1,2])), Optional(List[Int]([3]))])
    var flattened = iterated(nested^).flat_sequence()
    assert_equal(flattened.value(), List[Int]([1,2,3]))
    var maybe = List[Optional[Optional[Int]]]([Optional(Optional(1)),Optional(Optional[Int]()),Optional(Optional(3))])
    var compacted = iterated(maybe^).sequence_filter()
    assert_equal(compacted.value(),List[Int]([1,3]))
    var failed = iterated(List[Result[Int,String]]([Result[Int,String](Ok(1)),Result[Int,String](Err(String("missing")))])).sequence()
    assert_equal(failed^.swap().to_optional().value(),"missing")
    comptime V = ValidationFamily[ListMonoid[String]]
    var errors = List[Result[Int,List[String]]]([Result[Int,List[String]](Err(List[String](["one"]))),Result[Int,List[String]](Err(List[String](["two"])))])
    var collected = iterated(errors^).sequence[V]()
    assert_equal(len(collected^.swap().to_optional().value()),2)
    assert_true(Bool(pure_discard()))
    assert_equal(forwarded(List[Optional[Int]]([Optional(7)])).value()[0],7)
    var pulls = 0
    assert_false(Bool(iterated(Counted(Pointer(to=pulls),0,5)).map(stop).sequence()))
    assert_equal(pulls,2)
    pulls = 0
    assert_false(Bool(iterated(Counted(Pointer(to=pulls),0,5)).map(stop).sequence_void()))
    assert_equal(pulls,2)
    var branches = iterated(List[List[Int]]([List[Int]([1,2]),List[Int]([3,4])])).sequence()
    assert_equal(len(branches),4)
    assert_equal(branches[0],[1,3])
    assert_equal(branches[3],[2,4])
    var empty_flat = iterated(List[Optional[List[Int]]]()).flat_sequence()
    var empty_filter = iterated(List[Optional[Optional[Int]]]()).sequence_filter()
    assert_equal(len(empty_flat.value()),0)
    assert_equal(len(empty_filter.value()),0)
    assert_false(Bool(iterated(List[Optional[List[Int]]]([Optional[List[Int]]()])).flat_sequence()))
    assert_false(Bool(iterated(List[Optional[Optional[Int]]]([Optional[Optional[Int]]()])).sequence_filter()))
    # Existing explicit positional and named family/error slots remain valid.
    assert_true(Bool(iterated(List[Optional[Int]]()).sequence[OptionalFamily]()))
    assert_true(Bool(iterated(List[Optional[Int]]()).sequence[G=OptionalFamily]()))
    assert_true(Bool(iterated(List[Optional[Int]]()).sequence_void[OptionalFamily,Error]()))
    assert_true(Bool(iterated(List[Optional[List[Int]]]()).flat_sequence[G=OptionalFamily,X=Error]()))
    assert_true(Bool(iterated(List[Optional[Optional[Int]]]()).sequence_filter[OptionalFamily,Error]()))
    var external = iterated(List[Box[Int]]([Box(8)])).sequence[BoxMonad]()
    assert_equal(external.value,[8])
    _ = iterated(List[Box[Int]]([Box(8)])).sequence_void[BoxMonad]()
    var accumulated = iterated(List[Result[Int,List[String]]]([Result[Int,List[String]](Err(List[String](["one"]))),Result[Int,List[String]](Err(List[String](["two"])))] )).sequence_void[V]()
    assert_equal(len(accumulated^.swap().to_optional().value()),2)
