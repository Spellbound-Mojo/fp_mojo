"""Failure construction retains callback selection, exact errors and cleanup order."""
from std.testing import assert_equal
from std.memory import ArcPointer
from fp.algebra import OrElseIfContract
from fp.callables import BorrowOnceCallable, OnceUnary
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from test_context_family_ensure import Family

@fieldwise_init
struct Owner(Movable):
    var id: Int
    var trace: ArcPointer[String]
    def __deinit__(deinit self): self.trace[] += String(self.id)

@fieldwise_init
struct Predicate[P: Movable & Deinitable](BorrowOnceCallable):
    var owner: Owner
    var accepted: Bool
    var fail: Bool
    comptime Payload = Self.P
    comptime Result = Bool
    comptime Failure = Int
    def invoke_once(deinit self, ref value: Self.Payload) raises Int -> Bool:
        self.owner.trace[] += "p"
        if self.fail: raise 81
        return self.accepted

@fieldwise_init
struct Factory(BorrowOnceCallable):
    var owner: Owner
    var fail: Bool
    comptime Payload = Owner
    comptime Result = String
    comptime Failure = Int
    def invoke_once(deinit self, ref value: Owner) raises Int -> String:
        self.owner.trace[] += "f"
        if self.fail: raise 82
        return "new"

@fieldwise_init
struct Handler(OnceUnary):
    var owner: Owner
    var fail: Bool
    comptime Arg = String
    comptime Out = Result[Owner,String]
    comptime Error = Int
    def call_once(deinit self, var error: String) raises Int -> Self.Out:
        self.owner.trace[] += "h"
        if self.fail: raise 83
        return Ok(Owner(4,self.owner.trace))

def ensure[fail_family: Bool](accepted: Bool, mode: Int, stored: Bool) raises:
    var trace = ArcPointer(String())
    var source: Result[Owner,String]
    if stored: source = Err(String("old"))
    else: source = Ok(Owner(1,trace))
    var code = 0
    var output = 0
    try:
        var result = pipeline[Family[fail_family]](source^).raising[Int]().ensure(
            Predicate[Owner](Owner(2,trace),accepted,mode==1), Factory(Owner(3,trace),mode==2)).get()
        output = 1 if result.is_ok() else 2
        _ = result^
    except error:
        comptime assert type_of(error) == Int
        code = error
    var expected_code = 0
    var expected_output = 2
    var expected_trace = "23"
    if not stored:
        if mode == 1:
            expected_code = 81
            expected_output = 0
            expected_trace = "p231"
        elif accepted:
            expected_output = 1
            expected_trace = "p231"
        else:
            expected_code = 82 if mode == 2 else 731 if fail_family else 0
            expected_output = 0 if expected_code else 2
            expected_trace = "p2f31"
    assert_equal(code,expected_code)
    assert_equal(output,expected_output)
    assert_equal(trace[],expected_trace)

def recover[fail_family: Bool](accepted: Bool, mode: Int, success: Bool) raises where OrElseIfContract[Family[fail_family],Result[Owner,String],Predicate[String],Handler].Compatible:
    var trace = ArcPointer(String())
    var source: Result[Owner,String]
    if success: source = Ok(Owner(1,trace))
    else: source = Err(String("old"))
    var code = 0
    var output = 0
    try:
        var result = pipeline[Family[fail_family]](source^).raising[Int]().or_else_if(
            Predicate[String](Owner(2,trace),accepted,mode==1),Handler(Owner(3,trace),mode==2)).get()
        output = 1 if result.is_ok() else 2
        _ = result^
    except error:
        comptime assert type_of(error) == Int
        code = error
    var expected_code = 0
    var expected_output = 1
    var expected_trace = "231"
    if not success:
        if mode == 1:
            expected_code = 81
            expected_output = 0
            expected_trace = "p23"
        elif not accepted:
            expected_code = 731 if fail_family else 0
            expected_output = 0 if fail_family else 2
            expected_trace = "p23"
        elif mode == 2:
            expected_code = 83
            expected_output = 0
            expected_trace = "p2h3"
        else:
            expected_trace = "p2h34"
    assert_equal(code,expected_code)
    assert_equal(output,expected_output)
    assert_equal(trace[],expected_trace)

def main() raises:
    for accepted in [False,True]:
        for mode in range(3):
            ensure[False](accepted,mode,False)
            ensure[True](accepted,mode,False)
            recover[False](accepted,mode,False)
            recover[True](accepted,mode,False)
    ensure[False](False,1,True)
    ensure[True](False,1,True)
    recover[False](False,1,True)
    recover[True](False,1,True)
