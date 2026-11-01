"""Effectful observation retains owners and cleans up failed branches."""
from fp.functions import pipeline
from fp.iteration import iterated
from fp.algebra import ResultFamily, OptionalFamily, ListFamily
from fp.data import Result, Ok, Err
from fp.callables import BorrowOnceCallable, OnceUnary
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


@fieldwise_init
struct TVOwner(Movable):
    var name: String
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


def tv_observe(owner: TVOwner) -> Result[Int, String]:
    if owner.name == "fail": return Err(String("failed"))
    return Ok(owner.name.byte_length())


@fieldwise_init
struct TVOnce(BorrowOnceCallable):
    comptime Payload = TVOwner
    comptime Result = Optional[Int]
    var output: TVOwner
    def invoke_once(deinit self, ref payload: TVOwner) raises Never capturing -> Optional[Int]:
        return Optional(payload.name.byte_length() + self.output.name.byte_length())


@fieldwise_init
struct TVVoidOnce(OnceUnary):
    comptime Arg = TVOwner
    comptime Out = Optional[Int]
    var capture: TVOwner
    def call_once(deinit self, var value: TVOwner) -> Optional[Int]:
        return Optional(value.name.byte_length() + self.capture.name.byte_length())


def main() raises:
    var drops = ArcPointer(0)
    var owners = List[TVOwner]()
    owners.append(TVOwner("one", drops))
    owners.append(TVOwner("two", drops))
    var retained = pipeline(owners^).traverse_tap[ResultFamily[String]](tv_observe).get().raise_on_err()
    assert_equal(drops[], 0)
    assert_equal(retained[0].name, "one")
    assert_equal(retained[1].name, "two")
    _ = retained^
    assert_equal(drops[], 2)
    var failed = List[TVOwner]()
    failed.append(TVOwner("first", drops))
    failed.append(TVOwner("fail", drops))
    failed.append(TVOwner("unvisited", drops))
    var result = iterated(failed^).traverse_tap[ResultFamily[String]](tv_observe)
    assert_true(result.is_err())
    assert_equal(drops[], 5)
    var single = pipeline(Optional(TVOwner("keep", drops))).traverse_tap[OptionalFamily](TVOnce(TVOwner("callback", drops))).get()
    assert_equal(drops[], 6)
    var inner = single.take()
    var kept = inner.take()
    assert_equal(kept.name, "keep")
    _ = kept^
    assert_equal(drops[], 7)
    var capture = TVOwner("capture", drops)
    def tv_captured(value: Int) {var capture^} -> Optional[Int]:
        return Optional(capture.name.byte_length() + value)
    var values: List[Int] = [1, 2]
    var observed = pipeline(values^).traverse_tap[OptionalFamily](tv_captured).get()
    assert_equal(observed.take(), [1, 2])
    assert_equal(drops[], 7)
    _ = tv_captured^
    assert_equal(drops[], 8)
    var source = Result[TVOwner, TVOwner](Ok(TVOwner("input", drops)))
    var discarded = pipeline(source^).traverse_void[OptionalFamily](TVVoidOnce(TVOwner("callback", drops))).get()
    assert_true(discarded.take().is_ok())
    assert_equal(drops[], 10)
    var failed_source = Result[TVOwner, TVOwner](Err(TVOwner("original error", drops)))
    var skipped = pipeline(failed_source^).traverse_void[OptionalFamily](TVVoidOnce(TVOwner("skipped", drops))).get()
    assert_equal(drops[], 11)
    var error = skipped.take()
    assert_true(error.is_err())
    _ = error^
    assert_equal(drops[], 12)
