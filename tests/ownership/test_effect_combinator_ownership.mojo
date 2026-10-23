"""Effectful reduction and branching keep unique owners and cleanup on exit."""
from fp.functions import piped
from fp.iteration import iterated
from fp.algebra import ResultFamily, OptionalFamily
from fp.data import Result, Ok, Err
from fp.callables import MutableBinary, OnceThunk
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true

@fieldwise_init
struct EFOwner(Movable):
    var text: String
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct EFOwnedStep(MutableBinary):
    var capture: EFOwner
    comptime First = EFOwner
    comptime Second = EFOwner
    comptime Out = Result[EFOwner, String]
    def call_mut(mut self, var first: EFOwner, var second: EFOwner) -> Self.Out:
        if second.text == "fail": return Err(String("failed"))
        first.text += second.text + self.capture.text
        return Ok(first^)

@fieldwise_init
struct EFOnceFactory(OnceThunk):
    var capture: EFOwner
    comptime Out = Result[EFOwner, String]
    def call_once(deinit self) -> Self.Out: return Ok(self.capture^)

@fieldwise_init
struct EFOwnershipFailure(Movable):
    var text: String
    def into_text(deinit self) -> String: return self.text^

def ef_owned_predicate(owner: EFOwner) -> Optional[Bool]: return Optional(owner.text == "keep")
def ef_owned_raise(var total: EFOwner, var item: EFOwner) raises EFOwnershipFailure -> Result[EFOwner, String]:
    raise EFOwnershipFailure("native failure")

def ef_owned_items(drops: ArcPointer[Int], fail: Bool) -> List[EFOwner]:
    var values = List[EFOwner]()
    values.append(EFOwner("first", drops))
    values.append(EFOwner("fail" if fail else "last", drops))
    values.append(EFOwner("unvisited", drops))
    return values^

def main() raises:
    var drops = ArcPointer(0)
    var values = List[EFOwner]()
    values.append(EFOwner("a", drops)); values.append(EFOwner("b", drops))
    var total = iterated(values^).fold_effect[ResultFamily[String]](EFOwnedStep(EFOwner("!",drops)),EFOwner("start",drops)).raise_on_err()
    assert_equal(total.text,"starta!b!")
    assert_equal(drops[],3)
    _ = total^
    assert_equal(drops[],4)
    var failed = piped(ef_owned_items(drops,True)).fold_effect[ResultFamily[String]](EFOwnedStep(EFOwner("!",drops)),EFOwner("start",drops)).get()
    assert_true(failed.is_err()); assert_equal(drops[],9)
    var empty = iterated(List[EFOwner]()).fold_effect[ResultFamily[String]](EFOwnedStep(EFOwner("unused",drops)),EFOwner("initial",drops)).raise_on_err()
    assert_equal(empty.text,"initial"); assert_equal(drops[],10)
    _ = empty^
    assert_equal(drops[],11)
    var selected = piped(Result[Bool,String](Ok(True))).if_effect(EFOnceFactory(EFOwner("yes",drops)),EFOnceFactory(EFOwner("no",drops))).get().raise_on_err()
    assert_equal(selected.text,"yes"); assert_equal(drops[],12)
    _ = selected^
    assert_equal(drops[],13)
    var skipped = piped(Result[Bool,String](Err(String("skip")))).if_effect(EFOnceFactory(EFOwner("yes",drops)),EFOnceFactory(EFOwner("no",drops))).get()
    assert_true(skipped.is_err()); assert_equal(drops[],15)
    var seen = List[EFOwner]()
    seen.append(EFOwner("keep",drops)); seen.append(EFOwner("unvisited",drops))
    var accepted = iterated(seen^).any_effect[OptionalFamily](ef_owned_predicate)
    assert_true(accepted.take()); assert_equal(drops[],17)
    var message = String()
    try:
        _ = iterated(ef_owned_items(drops,False)).fold_effect[ResultFamily[String]](ef_owned_raise,EFOwner("acc",drops))
    except error:
        message = error^.into_text()
    assert_equal(message,"native failure"); assert_equal(drops[],21)
    # A native factory borrows its move-only capture; it does not copy it.
    var capture = EFOwner("native",drops)
    def native() {ref capture} -> Result[String,String]: return Ok(capture.text.copy())
    def unused() -> Result[String,String]: return Ok(String("unused"))
    var text = piped(Result[Bool,String](Ok(True))).if_effect(native,unused).get().raise_on_err()
    assert_equal(text,"native"); assert_equal(capture.text,"native")
    _ = capture^
    assert_equal(drops[],22)
