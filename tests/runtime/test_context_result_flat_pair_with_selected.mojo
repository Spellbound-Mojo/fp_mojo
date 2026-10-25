from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.testing import assert_equal
@fieldwise_init
struct ContextResultFlatPairWithFaultSelected(Movable):
    var code:Int
def check_pure() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(value: Int) -> Result[String,String]:
        return Ok(String(value))
    var result: Result[Tuple[Int,String],String]
    result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultFlatPairWithFaultSelected]().flat_pair_with(cb0).get()
    assert_equal(result._ok().value[1], "3")
    assert_equal(calls0 + calls1, 0)
def check_pure_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(value: Int) {mut calls0} -> Result[String,String]:
        calls0 += 1
        return Ok(String(value))
    var result: Result[Tuple[Int,String],String]
    result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultFlatPairWithFaultSelected]().flat_pair_with(cb0).get()
    assert_equal(result._ok().value[1], "3")
    assert_equal(calls0 + calls1, 1)
def check_never() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(value: Int) raises Never -> Result[String,String]:
        return Ok(String(value))
    var result: Result[Tuple[Int,String],String]
    result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultFlatPairWithFaultSelected]().flat_pair_with(cb0).get()
    assert_equal(result._ok().value[1], "3")
    assert_equal(calls0 + calls1, 0)
def check_never_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(value: Int) raises Never {mut calls0} -> Result[String,String]:
        calls0 += 1
        return Ok(String(value))
    var result: Result[Tuple[Int,String],String]
    result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultFlatPairWithFaultSelected]().flat_pair_with(cb0).get()
    assert_equal(result._ok().value[1], "3")
    assert_equal(calls0 + calls1, 1)
def check_error() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(value: Int) raises ContextResultFlatPairWithFaultSelected -> Result[String,String]:
        return Ok(String(value))
    var result: Result[Tuple[Int,String],String]
    try:
        result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultFlatPairWithFaultSelected]().flat_pair_with(cb0).get()
    except _: raise Error("unexpected native failure")
    assert_equal(result._ok().value[1], "3")
    assert_equal(calls0 + calls1, 0)
def check_error_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(value: Int) raises ContextResultFlatPairWithFaultSelected {mut calls0} -> Result[String,String]:
        calls0 += 1
        return Ok(String(value))
    var result: Result[Tuple[Int,String],String]
    try:
        result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultFlatPairWithFaultSelected]().flat_pair_with(cb0).get()
    except _: raise Error("unexpected native failure")
    assert_equal(result._ok().value[1], "3")
    assert_equal(calls0 + calls1, 1)
def main() raises:
    check_pure()
    check_pure_captured()
    check_never()
    check_never_captured()
    check_error()
    check_error_captured()
