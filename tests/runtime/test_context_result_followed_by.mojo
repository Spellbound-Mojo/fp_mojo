from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.testing import assert_equal
@fieldwise_init
struct ContextResultFollowedByFault(Movable):
    var code:Int
def check_pure() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0() -> Result[String,String]:
        return Ok(String("next"))
    var result: Result[String,String]
    result = pipeline(Result[Int,String](Ok(3))).raising[Never]().followed_by(cb0).get()
    assert_equal(result._ok().value, "next")
    assert_equal(calls0 + calls1, 0)
def check_pure_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0() {mut calls0} -> Result[String,String]:
        calls0 += 1
        return Ok(String("next"))
    var result: Result[String,String]
    result = pipeline(Result[Int,String](Ok(3))).raising[Never]().followed_by(cb0).get()
    assert_equal(result._ok().value, "next")
    assert_equal(calls0 + calls1, 1)
def check_never() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0() raises Never -> Result[String,String]:
        return Ok(String("next"))
    var result: Result[String,String]
    result = pipeline(Result[Int,String](Ok(3))).raising[Never]().followed_by(cb0).get()
    assert_equal(result._ok().value, "next")
    assert_equal(calls0 + calls1, 0)
def check_never_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0() raises Never {mut calls0} -> Result[String,String]:
        calls0 += 1
        return Ok(String("next"))
    var result: Result[String,String]
    result = pipeline(Result[Int,String](Ok(3))).raising[Never]().followed_by(cb0).get()
    assert_equal(result._ok().value, "next")
    assert_equal(calls0 + calls1, 1)
def check_error() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0() raises ContextResultFollowedByFault -> Result[String,String]:
        return Ok(String("next"))
    var result: Result[String,String]
    try:
        result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultFollowedByFault]().followed_by(cb0).get()
    except _: raise Error("unexpected native failure")
    assert_equal(result._ok().value, "next")
    assert_equal(calls0 + calls1, 0)
def check_error_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0() raises ContextResultFollowedByFault {mut calls0} -> Result[String,String]:
        calls0 += 1
        return Ok(String("next"))
    var result: Result[String,String]
    try:
        result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultFollowedByFault]().followed_by(cb0).get()
    except _: raise Error("unexpected native failure")
    assert_equal(result._ok().value, "next")
    assert_equal(calls0 + calls1, 1)
def main() raises:
    check_pure()
    check_pure_captured()
    check_never()
    check_never_captured()
    check_error()
    check_error_captured()
