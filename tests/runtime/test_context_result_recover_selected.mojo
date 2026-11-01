from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.testing import assert_equal
@fieldwise_init
struct ContextResultRecoverFaultSelected(Movable):
    var code:Int
def check_pure() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: String) -> Int:
        return value.byte_length()
    var result: Result[Int,String]
    result = pipeline(Result[Int,String](Err(String("bad")))).raising[ContextResultRecoverFaultSelected]().recover(cb0).get()
    assert_equal(result._ok().value, 3)
    assert_equal(calls0 + calls1, 0)
def check_pure_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: String) {mut calls0} -> Int:
        calls0 += 1
        return value.byte_length()
    var result: Result[Int,String]
    result = pipeline(Result[Int,String](Err(String("bad")))).raising[ContextResultRecoverFaultSelected]().recover(cb0).get()
    assert_equal(result._ok().value, 3)
    assert_equal(calls0 + calls1, 1)
def check_never() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: String) raises Never -> Int:
        return value.byte_length()
    var result: Result[Int,String]
    result = pipeline(Result[Int,String](Err(String("bad")))).raising[ContextResultRecoverFaultSelected]().recover(cb0).get()
    assert_equal(result._ok().value, 3)
    assert_equal(calls0 + calls1, 0)
def check_never_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: String) raises Never {mut calls0} -> Int:
        calls0 += 1
        return value.byte_length()
    var result: Result[Int,String]
    result = pipeline(Result[Int,String](Err(String("bad")))).raising[ContextResultRecoverFaultSelected]().recover(cb0).get()
    assert_equal(result._ok().value, 3)
    assert_equal(calls0 + calls1, 1)
def check_error() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: String) raises ContextResultRecoverFaultSelected -> Int:
        return value.byte_length()
    var result: Result[Int,String]
    try:
        result = pipeline(Result[Int,String](Err(String("bad")))).raising[ContextResultRecoverFaultSelected]().recover(cb0).get()
    except _: raise Error("unexpected native failure")
    assert_equal(result._ok().value, 3)
    assert_equal(calls0 + calls1, 0)
def check_error_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: String) raises ContextResultRecoverFaultSelected {mut calls0} -> Int:
        calls0 += 1
        return value.byte_length()
    var result: Result[Int,String]
    try:
        result = pipeline(Result[Int,String](Err(String("bad")))).raising[ContextResultRecoverFaultSelected]().recover(cb0).get()
    except _: raise Error("unexpected native failure")
    assert_equal(result._ok().value, 3)
    assert_equal(calls0 + calls1, 1)
def main() raises:
    check_pure()
    check_pure_captured()
    check_never()
    check_never_captured()
    check_error()
    check_error_captured()
