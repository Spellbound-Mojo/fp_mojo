from fp.functions import pipeline
from fp.data import Result, Ok, Err
from fp.callables import OnceUnary, BorrowOnceCallable
from std.testing import assert_equal
from std.memory import ArcPointer

@fieldwise_init
struct ContextResultBehaviorFault(Movable):
    var code: Int

@fieldwise_init
struct ContextResultBehaviorOwner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct ContextResultBehaviorRecovery(OnceUnary):
    var calls: ArcPointer[Int]
    var drops: ContextResultBehaviorOwner
    comptime Arg = ContextResultBehaviorOwner
    comptime Out = ContextResultBehaviorOwner
    comptime Error = Never
    def call_once(deinit self, var value: ContextResultBehaviorOwner) -> ContextResultBehaviorOwner:
        self.calls[] += 1
        return value^

@fieldwise_init
struct ContextResultBehaviorPredicate(BorrowOnceCallable):
    var calls: ArcPointer[Int]
    var accept: Bool
    comptime Payload = ContextResultBehaviorOwner
    comptime Result = Bool
    comptime Failure = Never
    def invoke_once(deinit self, value: ContextResultBehaviorOwner) -> Bool:
        self.calls[] += 1
        return self.accept

def main() raises:
    var calls = ArcPointer(0)
    var drops = ArcPointer(0)
    var owners = ArcPointer(0)
    var rejected = pipeline(Result[ContextResultBehaviorOwner,ContextResultBehaviorOwner](Err(ContextResultBehaviorOwner(7, owners)))).recover_if(ContextResultBehaviorPredicate(calls, False), ContextResultBehaviorRecovery(calls, ContextResultBehaviorOwner(0, drops))).get()
    assert_equal(calls[], 1)
    assert_equal(drops[], 1)
    assert_equal(rejected._err().value.value, 7)
    _ = rejected^
    assert_equal(owners[], 1)
    var recovered = pipeline(Result[ContextResultBehaviorOwner,ContextResultBehaviorOwner](Err(ContextResultBehaviorOwner(8, owners)))).recover_if(ContextResultBehaviorPredicate(calls, True), ContextResultBehaviorRecovery(calls, ContextResultBehaviorOwner(0, drops))).get()
    assert_equal(calls[], 3)
    assert_equal(recovered._ok().value.value, 8)
    _ = recovered^
    assert_equal(owners[], 2)
    assert_equal(drops[], 2)
    var skipped = pipeline(Result[ContextResultBehaviorOwner,ContextResultBehaviorOwner](Ok(ContextResultBehaviorOwner(9, owners)))).recover_if(ContextResultBehaviorPredicate(calls, True), ContextResultBehaviorRecovery(calls, ContextResultBehaviorOwner(0, drops))).get()
    assert_equal(calls[], 3)
    assert_equal(drops[], 3)
    assert_equal(skipped._ok().value.value, 9)
    _ = skipped^
    assert_equal(owners[], 3)
    var native_calls = 0
    def fail(value: String) raises ContextResultBehaviorFault {mut native_calls} -> Bool:
        native_calls += 1
        raise ContextResultBehaviorFault(31)
    def fallback(var value: String) -> Int: return value.byte_length()
    var code = 0
    try:
        _ = pipeline(Result[Int,String](Err(String("bad")))).raising[ContextResultBehaviorFault]().recover_if(fail, fallback).get()
    except error:
        code = error.code
    assert_equal(code, 31)
    assert_equal(native_calls, 1)
    def observe(value: String) {mut native_calls}:
        native_calls += value.byte_length()
    var inspected = pipeline(Result[Int,String](Err(String("bad")))).tap_err(observe).get()
    assert_equal(inspected._err().value, "bad")
    assert_equal(native_calls, 4)
