"""Result combinators retain move-only owners and release every branch once."""
from fp.data import Result, Ok, Err
from fp.functions import piped
from fp.callables import BorrowOnceCallable, OnceThunk
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


@fieldwise_init
struct RCOwner(Movable):
    var name: String
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1


def rco_text(var text: String) -> String: return text^

def rco_name(var owner: RCOwner) -> String: return owner.name.copy()
def rco_positive(owner: RCOwner) -> Bool: return owner.name == "keep"
def rco_pair(var pair: Tuple[RCOwner, RCOwner]) -> String:
    return pair[0].name + ":" + pair[1].name


@fieldwise_init
struct RCOProject(BorrowOnceCallable):
    var output: RCOwner
    var fail: Bool
    comptime Payload = RCOwner
    comptime Result = Result[RCOwner, RCOwner]
    def invoke_once(deinit self, ref payload: Self.Payload) raises Never capturing -> Self.Result:
        if self.fail: return Err(self.output^)
        return Ok(self.output^)


@fieldwise_init
struct RCOFactory(OnceThunk):
    var output: RCOwner
    comptime Out = Result[RCOwner, RCOwner]
    def call_once(deinit self) -> Self.Out:
        return Ok(self.output^)


@fieldwise_init
struct RCOInspect(BorrowOnceCallable):
    var output: RCOwner
    var calls: ArcPointer[Int]
    comptime Payload = RCOwner
    comptime Result = RCOwner
    def invoke_once(deinit self, ref payload: Self.Payload) raises Never capturing -> Self.Result:
        self.calls[] += 1
        return self.output^


def rco_retention() raises:
    var inputs = ArcPointer(0)
    var outputs = ArcPointer(0)
    var tapped = Result[RCOwner, RCOwner](Ok(RCOwner("keep", inputs)))
    var retained = tapped^.flat_tap(RCOProject(RCOwner("discard", outputs), False))
    assert_equal(inputs[], 0)
    assert_equal(outputs[], 1)
    assert_equal(retained^.fold_owned(rco_name, rco_name), "keep")
    assert_equal(inputs[], 1)
    var paired = Result[RCOwner, RCOwner](Ok(RCOwner("first", inputs)))
    var both = paired^.flat_pair_with(RCOProject(RCOwner("second", outputs), False))
    assert_equal(inputs[], 1)
    assert_equal(outputs[], 1)
    assert_equal(both^.fold_owned(rco_pair, rco_name), "first:second")
    assert_equal(inputs[], 2)
    assert_equal(outputs[], 2)
    var rejected = Result[RCOwner, RCOwner](Ok(RCOwner("drop", inputs)))
    var failure = rejected^.flat_tap(RCOProject(RCOwner("error", outputs), True))
    assert_equal(inputs[], 3)
    assert_equal(outputs[], 2)
    assert_equal(failure^.fold_owned(rco_name, rco_name), "error")
    assert_equal(outputs[], 3)
    var skipped = Result[RCOwner, RCOwner](Err(RCOwner("old error", inputs)))
    var unchanged = skipped^.flat_pair_with(RCOProject(RCOwner("unused capture", outputs), False))
    assert_equal(outputs[], 4)
    assert_equal(inputs[], 3)
    assert_equal(unchanged^.fold_owned(rco_pair, rco_name), "old error")
    assert_equal(inputs[], 4)


def rco_other_branches() raises:
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var value = Result[RCOwner, RCOwner](Ok(RCOwner("keep", drops)))
    var kept = piped(value^).before(RCOFactory(RCOwner("ignored", drops))).get()
    assert_equal(drops[], 1)
    assert_equal(kept^.fold_owned(rco_name, rco_name), "keep")
    assert_equal(drops[], 2)
    var next = Result[RCOwner, RCOwner](Ok(RCOwner("old", drops)))
    var advanced = next^.followed_by(RCOFactory(RCOwner("new", drops)))
    assert_equal(drops[], 3)
    assert_equal(advanced^.fold_owned(rco_name, rco_name), "new")
    assert_equal(drops[], 4)
    var error = Result[RCOwner, RCOwner](Err(RCOwner("error", drops)))
    var observed = error^.tap_err(RCOInspect(RCOwner("inspector result", drops), calls))
    assert_equal(calls[], 1)
    assert_equal(drops[], 5)
    assert_equal(observed^.fold_owned(rco_name, rco_name), "error")
    assert_equal(drops[], 6)
    var passing = Result[RCOwner, RCOwner](Ok(RCOwner("keep", drops)))
    var checked = passing^.ensure(rco_positive, RCOInspect(RCOwner("unused error", drops), calls))
    assert_equal(calls[], 1)
    assert_equal(drops[], 7)
    assert_equal(checked^.fold_owned(rco_name, rco_name), "keep")
    assert_equal(drops[], 8)
    var reject = Result[RCOwner, RCOwner](Ok(RCOwner("reject", drops)))
    var checked_error = reject^.ensure(rco_positive, RCOInspect(RCOwner("invalid", drops), calls))
    assert_equal(calls[], 2)
    assert_equal(drops[], 9)
    assert_equal(checked_error^.fold_owned(rco_name, rco_name), "invalid")
    assert_equal(drops[], 10)
    var recoverable = Result[String, RCOwner](Err(RCOwner("recovered", drops)))
    assert_equal(recoverable^.recover(rco_name).fold_owned(rco_text, rco_name), "recovered")
    assert_equal(drops[], 11)


def rco_origins_and_native_capture(values: List[Int]) raises:
    var view = Span(values)
    def rco_view(value: Int) {view} -> Result[type_of(view), String]:
        return Ok(view)
    var subject = Result[Int, String](Ok(3))
    var pair = subject^.flat_pair_with(rco_view).raise_on_err()
    comptime assert type_of(pair) == Tuple[Int, type_of(view)]
    assert_equal(pair[0], 3)
    assert_equal(pair[1][1], 9)
    var source = Result[type_of(view), String](Ok(view))
    comptime View = type_of(view)
    def rco_span_size(value: View) -> Result[Int, String]:
        return Ok(len(value))
    var original = source^.flat_tap(rco_span_size).raise_on_err()
    comptime assert type_of(original) == type_of(view)
    assert_equal(original[0], 7)
    var drops = ArcPointer(0)
    var capture = RCOwner("captured", drops)
    def rco_captured(value: Int) {var capture^} -> Result[String, String]:
        return Ok(capture.name.copy() + String(value))
    var captured_input = Result[Int, String](Ok(2))
    var capture_pair = piped(captured_input^).flat_pair_with(rco_captured).get().raise_on_err()
    assert_equal(capture_pair[1], "captured2")
    assert_equal(drops[], 0)
    _ = rco_captured^
    assert_equal(drops[], 1)


def main() raises:
    rco_retention()
    rco_other_branches()
    var values: List[Int] = [7, 9]
    rco_origins_and_native_capture(values)
