"""Traversal filtering and flattening preserve unique owners and their cleanup."""
from fp.functions import pipeline
from fp.iteration import iterated
from fp.iteration import sequence_void
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Ok, Err
from fp.callables import BorrowOnceCallable, OnceUnary
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


@fieldwise_init
struct TXOwner(Movable):
    var name: String
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


def tx_decide(owner: TXOwner) -> Result[Bool, String]:
    if owner.name == "fail": return Err(String("failed"))
    return Ok(owner.name == "keep")


def tx_owned_optional(var owner: TXOwner) -> Result[Optional[TXOwner], String]:
    if owner.name == "keep": return Ok(Optional(owner^))
    return Ok(Optional[TXOwner]())


def tx_owned_group(var owner: TXOwner) -> Optional[List[TXOwner]]:
    var items = List[TXOwner]()
    items.append(owner^)
    return Optional(items^)


@fieldwise_init
struct TXOnceDecision(BorrowOnceCallable):
    var capture: TXOwner
    comptime Payload = TXOwner
    comptime Result = Optional[Bool]
    def invoke_once(deinit self, ref value: TXOwner) raises Never capturing -> Optional[Bool]:
        return Optional(value.name == self.capture.name)


@fieldwise_init
struct TXOnceGroup(OnceUnary):
    var capture: TXOwner
    comptime Arg = TXOwner
    comptime Out = Optional[Optional[TXOwner]]
    def call_once(deinit self, var value: TXOwner) -> Self.Out:
        return Optional(Optional(value^))


def tx_keep() raises:
    var drops = ArcPointer(0)
    var items = List[TXOwner]()
    items.append(TXOwner("drop", drops))
    items.append(TXOwner("keep", drops))
    var kept = pipeline(items^).filter_effect[ResultFamily[String]](tx_decide).get().raise_on_err()
    assert_equal(drops[], 1)
    assert_equal(kept[0].name, "keep")
    _ = kept^
    assert_equal(drops[], 2)
    var transformed = List[TXOwner]()
    transformed.append(TXOwner("drop", drops))
    transformed.append(TXOwner("keep", drops))
    var selected = iterated(transformed^).traverse_filter[ResultFamily[String]](tx_owned_optional).raise_on_err()
    assert_equal(drops[], 3)
    assert_equal(selected[0].name, "keep")
    var flattened = pipeline(selected^).flat_traverse[OptionalFamily](tx_owned_group).get()
    var output = flattened.take()
    assert_equal(output[0].name, "keep")
    assert_equal(drops[], 3)
    _ = output^
    assert_equal(drops[], 4)


def tx_cleanup() raises:
    var drops = ArcPointer(0)
    var items = List[TXOwner]()
    items.append(TXOwner("keep", drops))
    items.append(TXOwner("fail", drops))
    items.append(TXOwner("unvisited", drops))
    assert_true(iterated(items^).filter_effect[ResultFamily[String]](tx_decide).is_err())
    assert_equal(drops[], 3)
    var single = pipeline(Optional(TXOwner("keep", drops))).filter_effect[OptionalFamily](TXOnceDecision(TXOwner("keep", drops))).get()
    assert_equal(drops[], 4)
    var inner = single.take()
    assert_equal(inner.value().name, "keep")
    _ = inner^
    assert_equal(drops[], 5)
    var absent = pipeline(Optional[TXOwner]()).filter_effect[OptionalFamily](TXOnceDecision(TXOwner("skipped", drops))).get()
    assert_equal(drops[], 6)
    _ = absent^
    var flat = pipeline(Optional(TXOwner("owned", drops))).flat_traverse[OptionalFamily](TXOnceGroup(TXOwner("capture", drops))).get()
    assert_equal(drops[], 7)
    var result = flat.take()
    assert_equal(result.value().name, "owned")
    _ = result^
    assert_equal(drops[], 8)
    var effects = List[Optional[TXOwner]]()
    effects.append(Optional(TXOwner("discard", drops)))
    effects.append(Optional(TXOwner("discard", drops)))
    assert_true(sequence_void[OptionalFamily](effects^))
    assert_equal(drops[], 10)
    var source_error = Result[Optional[TXOwner], TXOwner](Err(TXOwner("original", drops)))
    var preserved = pipeline(source_error^).sequence_void[OptionalFamily]().get()
    var failed = preserved.take()
    assert_equal(drops[], 10)
    var stored = failed^._take_err()
    assert_equal(stored.name, "original")
    _ = stored^
    assert_equal(drops[], 11)


def tx_native_capture() raises:
    var drops = ArcPointer(0)
    var capture = TXOwner("closure", drops)
    def decision(value: Int) {var capture^} -> Optional[Bool]:
        return Optional(value == capture.name.byte_length())
    var values: List[Int] = [6, 7, 8]
    var result = pipeline(values^).filter_effect[OptionalFamily](decision).get()
    assert_equal(result.take(), [7])
    assert_equal(drops[], 0)
    _ = decision^
    assert_equal(drops[], 1)
    var owners = List[TXOwner]()
    owners.append(TXOwner("raise", drops))
    owners.append(TXOwner("unvisited", drops))
    def raising(owner: TXOwner) raises String -> Optional[Bool]: raise String(owner.name)
    var message = String()
    try: _ = iterated(owners^).filter_effect[OptionalFamily](raising)
    except error: message = error^
    assert_equal(message, "raise")
    assert_equal(drops[], 3)


def main() raises:
    tx_keep()
    tx_cleanup()
    tx_native_capture()
