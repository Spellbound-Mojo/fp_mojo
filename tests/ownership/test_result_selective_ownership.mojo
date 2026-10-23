"""Selective recovery keeps move-only owners, captures and external origins."""
from fp.data import Result, Ok, Err
from fp.functions import piped
from fp.callables import BorrowOnceCallable, OnceUnary
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct RSOOwner(Movable):
    var name: String
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


def rso_name(var owner: RSOOwner) -> String: return owner.name.copy()
def rso_accept(owner: RSOOwner) -> Bool: return owner.name == "retry"


@fieldwise_init
struct RSOGuard(BorrowOnceCallable):
    var capture: RSOOwner
    var throws: Bool
    comptime Payload = RSOOwner
    comptime Result = Bool
    comptime Failure = String
    def invoke_once(deinit self, ref value: RSOOwner) raises String capturing -> Bool:
        if self.throws: raise String("predicate")
        return rso_accept(value)


@fieldwise_init
struct RSORestore(OnceUnary):
    var output: RSOOwner
    var throws: Bool
    comptime Arg = RSOOwner
    comptime Out = RSOOwner
    comptime Error = String
    def call_once(deinit self, var value: RSOOwner) raises String -> RSOOwner:
        if self.throws: raise String("recovery")
        return self.output^


@fieldwise_init
struct RSOInspect(BorrowOnceCallable):
    var output: RSOOwner
    var fail: Bool
    comptime Payload = RSOOwner
    comptime Result = Result[RSOOwner, RSOOwner]
    def invoke_once(deinit self, ref value: RSOOwner) raises Never capturing -> Self.Result:
        if self.fail: return Err(self.output^)
        return Ok(self.output^)


@fieldwise_init
struct RSOFailInspect(BorrowOnceCallable):
    var capture: RSOOwner
    comptime Payload = RSOOwner
    comptime Result = Result[Int, RSOOwner]
    comptime Failure = String
    def invoke_once(deinit self, ref value: RSOOwner) raises String capturing -> Self.Result:
        raise self.capture.name.copy()


def rso_selective() raises:
    # Independent counters distinguish discarded callbacks from retained data.
    for branch in range(5):
        var inputs = ArcPointer(0)
        var predicates = ArcPointer(0)
        var recoveries = ArcPointer(0)
        var input = RSOOwner("keep" if branch == 1 else "retry", inputs)
        var source = Result[RSOOwner, RSOOwner](Ok(input^)) if branch == 0 else Result[RSOOwner, RSOOwner](Err(input^))
        var guard = RSOGuard(RSOOwner("guard", predicates), branch == 3)
        var recovery = RSORestore(RSOOwner("restored", recoveries), branch == 4)
        var message: String
        var input_drops = -1
        var recovery_drops = -1
        var predicate_drops = -1
        try:
            var result = piped(source^).recover_if(guard^, recovery^).get()
            predicate_drops = predicates[]
            input_drops = inputs[]
            recovery_drops = recoveries[]
            message = result^.fold_owned(rso_name, rso_name)
        except error: message = error^
        if branch < 3:
            assert_equal(predicate_drops, 1)
            assert_equal(input_drops, 1 if branch == 2 else 0)
            assert_equal(recovery_drops, 0 if branch == 2 else 1)
        assert_equal(message, "retry" if branch == 0 else "keep" if branch == 1 else "restored" if branch == 2 else "predicate" if branch == 3 else "recovery")
        assert_equal(inputs[], 1)
        assert_equal(predicates[], 1)
        assert_equal(recoveries[], 1)


def rso_observation() raises:
    for branch in range(3):
        var inputs = ArcPointer(0)
        var outputs = ArcPointer(0)
        var input = RSOOwner("original", inputs)
        var source = Result[RSOOwner, RSOOwner](Ok(input^)) if branch == 0 else Result[RSOOwner, RSOOwner](Err(input^))
        var result = source^.flat_tap_err(RSOInspect(RSOOwner("replacement", outputs), branch == 2))
        assert_equal(inputs[], 1 if branch == 2 else 0)
        assert_equal(outputs[], 0 if branch == 2 else 1)
        assert_equal(result^.fold_owned(rso_name, rso_name), "replacement" if branch == 2 else "original")
        assert_equal(inputs[], 1)
        assert_equal(outputs[], 1)
    var inputs = ArcPointer(0)
    var captures = ArcPointer(0)
    var raised = String()
    try:
        var source = Result[Int, RSOOwner](Err(RSOOwner("original", inputs)))
        _ = source^.flat_tap_err(RSOFailInspect(RSOOwner("observer", captures)))
    except error: raised = error^
    assert_equal(raised, "observer")
    assert_equal(inputs[], 1)
    assert_equal(captures[], 1)


def rso_origins(values: List[Int]) raises:
    var view = Span(values)
    comptime View = type_of(view)
    def rso_no(error: View) -> Bool: return False
    def rso_unused(var error: View) -> View: return error
    var source = Result[View, View](Err(view))
    var retained = source^.recover_if(rso_no, rso_unused)
    comptime assert type_of(retained) == Result[View, View]
    def rso_read(var value: View) -> Int: return value[1]
    assert_equal(retained^.fold_owned(rso_read, rso_read), 9)
    var drops = ArcPointer(0)
    var capture = RSOOwner("capture", drops)
    def rso_return_view(var error: RSOOwner) {view, var capture^} -> Result[View, RSOOwner]:
        assert capture.name == "capture"
        return Ok(view)
    var recoverable = Result[View, RSOOwner](Err(RSOOwner("retry", drops)))
    var result = piped(recoverable^).or_else_if(rso_accept, rso_return_view).get()
    assert_equal(drops[], 1)
    # The native closure stays callable after the chain; its capture is borrowed.
    _ = rso_return_view(RSOOwner("again", drops))
    assert_equal(drops[], 2)
    _ = rso_return_view^
    assert_equal(drops[], 3)
    def rso_error(var error: RSOOwner) -> Int: return -1
    assert_equal(result^.fold_owned(rso_read, rso_error), 9)


def main() raises:
    rso_selective()
    rso_observation()
    var values: List[Int] = [7, 9]
    rso_origins(values)
