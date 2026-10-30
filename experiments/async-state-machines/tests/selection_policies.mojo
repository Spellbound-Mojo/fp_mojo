"""Cancellation-aware selection shares the first-terminal draining engine."""
from foundation import at
from std.memory import ArcPointer
from std.builtin.rebind import rebind_var
from fp.data import Left, Right, Result, Err, NonEmptyList
from fp.effects import IOContext, EffectFailure, CancellationToken
from state_machine import Machine, Step, Wait, Signal, Driver, Clock, IO, RaceResult, pure, run, uncancelable
from foundation import check, success, Resource, race, race_first, timeout_to, timeout_after


@fieldwise_init
struct GatedResult(Machine):
    var gate: Signal
    var mode: Int
    var entered: Bool
    comptime Value = Int
    comptime Error = Int
    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        if context.canceled():
            return .ready(None)
        if not self.entered:
            self.entered = True
            return .pending(Wait.changed(self.gate, self.gate.revision()))
        if self.mode == 2:
            return .ready(None)
        if self.mode == 1:
            return .ready(Optional(Result[Int, EffectFailure[Int]](Err(EffectFailure(NonEmptyList(19), False)))))
        return success[Int, Int](42)


@fieldwise_init
struct Fallback(Machine):
    var calls: ArcPointer[Int]
    comptime Value = Int
    comptime Error = Int
    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        self.calls[] += 1
        return success[Int, Int](7)


@fieldwise_init
struct OwnedResult(Machine):
    var gate: Signal
    var value: Optional[Resource]
    var entered: Bool
    comptime Value = Resource
    comptime Error = Int
    def poll(mut self, context: IOContext[Int]) -> Step[Resource, Int]:
        if not self.entered:
            self.entered = True
            return .pending(Wait.changed(self.gate, self.gate.revision()))
        return success[Resource, Int](self.value.take())


def owned_selection():
    var first = Signal()
    var second = Signal()
    var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
    var protected = uncancelable(OwnedResult(second.copy(), Optional(Resource(String("retained GPU-independent owner"), stats.copy())), False))
    var driver = Driver(race(GatedResult(first.copy(), 2, False), protected^))
    _ = driver.poll(100)
    first.notify()
    check(not driver.poll(100).completed and stats[][3] == 0, "owned value survives canceled-first draining")
    second.notify()
    check(driver.poll(100).completed and stats[][3] == 0, "selected owner transfers to the result")
    var outcome = driver^.finish()
    var payload = outcome.take()._take_ok().unwrap[Right[Resource]]().into_payload()
    check(payload.text == "retained GPU-independent owner", "owned result remains usable")
    _ = payload^
    check(stats[][3] == 1, "selected move-only value is destroyed exactly once")


def canceled_first[left_first: Bool, first_policy: Bool]():
    var first = Signal()
    var second = Signal()
    var a = GatedResult(first.copy(), 2, False)
    var b = uncancelable(GatedResult(second.copy(), 0, False))
    var program: IO[RaceResult[GatedResult.Value, GatedResult.Value], GatedResult.Error]
    comptime if left_first:
        comptime if first_policy:
            program = rebind_var[type_of(program)](race_first(a^, b^))
        else:
            program = rebind_var[type_of(program)](race(a^, b^))
    else:
        comptime if first_policy:
            program = rebind_var[type_of(program)](race_first(b^, a^))
        else:
            program = rebind_var[type_of(program)](race(b^, a^))
    var driver = Driver(program^)
    check(not driver.poll(100).runnable, "both arms enter before arbitration")
    first.notify()
    check(not driver.poll(100).completed, "first cancellation still drains the masked arm")
    second.notify()
    check(driver.poll(100).completed, "surviving arm completes")
    var outcome = driver^.finish()
    comptime if first_policy:
        check(not outcome, "first-terminal policy retains selected cancellation")
    else:
        var value = outcome.take()._take_ok()
        check(value.isa[Right[Int]]() == left_first, "cancellation-aware policy selects the surviving arm")


def deadline[prefer_source: Bool](mode: Int, cancel_parent: Bool):
    var gate = Signal()
    var calls = ArcPointer(0)
    var clock = Clock.manual()
    var source = uncancelable(GatedResult(gate.copy(), mode, False))
    var program: IO[GatedResult.Value, GatedResult.Error]
    comptime if prefer_source:
        program = rebind_var[type_of(program)](timeout_to(source^, 10, Fallback(calls.copy())))
    else:
        program = rebind_var[type_of(program)](timeout_after(source^, 10, Fallback(calls.copy())))
    var driver = Driver(program^, CancellationToken(), clock)
    check(driver.poll(100).deadline.value() == at(10), "deadline is armed")
    clock.advance_to(at(10))
    check(not driver.poll(100).completed and calls[] == 0, "timer cannot abandon masked source")
    if cancel_parent:
        driver.cancel()
    gate.notify()
    check(driver.poll(100).completed, "source drains before selection")
    var outcome = driver^.finish()
    if mode == 1:
        var failure = outcome.take()._take_err()
        check(failure.errors.first() == 19, "late source failure is retained")
        check(failure.canceled == (prefer_source or cancel_parent), "selected failure retains cancellation; losing cancellation is normalized")
        check(calls[] == 0, "failure prevents fallback")
    elif cancel_parent:
        check(not outcome and calls[] == 0, "parent cancellation skips fallback and success")
    else:
        var use_source = prefer_source and mode == 0
        check(outcome.take()._take_ok() == (42 if use_source else 7), "timeout selection policy")
        check(calls[] == Int(not use_source), "fallback enters exactly when selected")


def main():
    owned_selection()
    canceled_first[True, True]()
    canceled_first[False, True]()
    canceled_first[True, False]()
    canceled_first[False, False]()
    for mode in range(3):
        for canceled in range(2):
            deadline[True](mode, Bool(canceled))
            deadline[False](mode, Bool(canceled))
    var both_canceled = run(race(GatedResult(Signal(), 2, True), GatedResult(Signal(), 2, True)))
    check(not both_canceled, "both canceled yields terminal cancellation")
    var masked = run(uncancelable(race(GatedResult(Signal(), 2, True), GatedResult(Signal(), 2, True))))
    check(not masked, "explicit canceled outcomes remain terminal under a mask")
    print("selection: both race policies, timeout source preference, draining, errors, parent cancellation")
