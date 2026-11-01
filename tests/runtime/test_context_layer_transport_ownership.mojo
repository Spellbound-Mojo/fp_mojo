"""Direct layer scopes preserve callback, payload and native-error ownership."""
from fp.algebra import pure
from fp.effects import Reader, OptionalT, ResultT, LiftLocal, local, run
from fp.callables import BorrowOnceCallable
from test_context_failure_forwarding_ownership import Owner
from std.memory import ArcPointer

@fieldwise_init
struct Change(BorrowOnceCallable):
    var capture: Owner
    var fail: Bool
    comptime Payload = Int
    comptime Result = Int
    comptime Failure = Owner
    def invoke_once(deinit self, ref env: Int) raises Owner -> Int:
        self.capture.trace[] += "c"
        if self.fail:
            raise Owner(7,self.capture.trace)
        return env + 1

def optional[execute: Bool,fail: Bool]() -> String:
    comptime R = Reader[Int]
    comptime I = OptionalT[R]
    comptime C = LiftLocal[I,R]
    var trace = ArcPointer(String())
    var pending = local[C](pure[I](Owner(2,trace)),Change(Owner(9,trace),fail))
    trace[] += "d"
    if execute:
        try:
            var output = run[R](pending^,0)
            trace[] += "r"
            _ = output^
        except error:
            comptime assert type_of(error) == Owner
            trace[] += "e"
            _ = error^
    else:
        _ = pending^
    trace[] += "z"
    return trace[].copy()

def result[execute: Bool,fail: Bool]() -> String:
    comptime R = Reader[Int]
    comptime I = ResultT[R,String]
    comptime C = LiftLocal[I,R]
    var trace = ArcPointer(String())
    var pending = local[C](pure[I](Owner(2,trace)),Change(Owner(9,trace),fail))
    trace[] += "d"
    if execute:
        try:
            var output = run[R](pending^,0)
            trace[] += "r"
            _ = output^
        except error:
            comptime assert type_of(error) == Owner
            trace[] += "e"
            _ = error^
    else:
        _ = pending^
    trace[] += "z"
    return trace[].copy()

from std.testing import assert_equal

def main() raises:
    assert_equal(optional[True,False](), "dc9r2z")
    assert_equal(optional[True,True](), "dc92e7z")
    assert_equal(optional[False,False](), "d29z")
    assert_equal(result[True,False](), "dc9r2z")
    assert_equal(result[True,True](), "dc92e7z")
    assert_equal(result[False,False](), "d29z")
