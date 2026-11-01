from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.testing import assert_equal
@fieldwise_init
struct ContextResultRedeemFaultSelected(Movable):
    var code:Int
def check_pure_pure() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) -> String:
        return String(value)
    def cb1(var value: String) -> String:
        return value^
    var result: Result[String,String]
    result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 0)
def check_pure_pure_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) {mut calls0} -> String:
        calls0 += 1
        return String(value)
    def cb1(var value: String) {mut calls1} -> String:
        calls1 += 1
        return value^
    var result: Result[String,String]
    result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 1)
def check_pure_never() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) -> String:
        return String(value)
    def cb1(var value: String) raises Never -> String:
        return value^
    var result: Result[String,String]
    result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 0)
def check_pure_never_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) {mut calls0} -> String:
        calls0 += 1
        return String(value)
    def cb1(var value: String) raises Never {mut calls1} -> String:
        calls1 += 1
        return value^
    var result: Result[String,String]
    result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 1)
def check_pure_error() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) -> String:
        return String(value)
    def cb1(var value: String) raises ContextResultRedeemFaultSelected -> String:
        return value^
    var result: Result[String,String]
    try:
        result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    except _: raise Error("unexpected native failure")
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 0)
def check_pure_error_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) {mut calls0} -> String:
        calls0 += 1
        return String(value)
    def cb1(var value: String) raises ContextResultRedeemFaultSelected {mut calls1} -> String:
        calls1 += 1
        return value^
    var result: Result[String,String]
    try:
        result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    except _: raise Error("unexpected native failure")
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 1)
def check_never_pure() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) raises Never -> String:
        return String(value)
    def cb1(var value: String) -> String:
        return value^
    var result: Result[String,String]
    result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 0)
def check_never_pure_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) raises Never {mut calls0} -> String:
        calls0 += 1
        return String(value)
    def cb1(var value: String) {mut calls1} -> String:
        calls1 += 1
        return value^
    var result: Result[String,String]
    result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 1)
def check_never_never() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) raises Never -> String:
        return String(value)
    def cb1(var value: String) raises Never -> String:
        return value^
    var result: Result[String,String]
    result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 0)
def check_never_never_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) raises Never {mut calls0} -> String:
        calls0 += 1
        return String(value)
    def cb1(var value: String) raises Never {mut calls1} -> String:
        calls1 += 1
        return value^
    var result: Result[String,String]
    result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 1)
def check_never_error() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) raises Never -> String:
        return String(value)
    def cb1(var value: String) raises ContextResultRedeemFaultSelected -> String:
        return value^
    var result: Result[String,String]
    try:
        result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    except _: raise Error("unexpected native failure")
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 0)
def check_never_error_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) raises Never {mut calls0} -> String:
        calls0 += 1
        return String(value)
    def cb1(var value: String) raises ContextResultRedeemFaultSelected {mut calls1} -> String:
        calls1 += 1
        return value^
    var result: Result[String,String]
    try:
        result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    except _: raise Error("unexpected native failure")
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 1)
def check_error_pure() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) raises ContextResultRedeemFaultSelected -> String:
        return String(value)
    def cb1(var value: String) -> String:
        return value^
    var result: Result[String,String]
    try:
        result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    except _: raise Error("unexpected native failure")
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 0)
def check_error_pure_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) raises ContextResultRedeemFaultSelected {mut calls0} -> String:
        calls0 += 1
        return String(value)
    def cb1(var value: String) {mut calls1} -> String:
        calls1 += 1
        return value^
    var result: Result[String,String]
    try:
        result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    except _: raise Error("unexpected native failure")
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 1)
def check_error_never() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) raises ContextResultRedeemFaultSelected -> String:
        return String(value)
    def cb1(var value: String) raises Never -> String:
        return value^
    var result: Result[String,String]
    try:
        result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    except _: raise Error("unexpected native failure")
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 0)
def check_error_never_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) raises ContextResultRedeemFaultSelected {mut calls0} -> String:
        calls0 += 1
        return String(value)
    def cb1(var value: String) raises Never {mut calls1} -> String:
        calls1 += 1
        return value^
    var result: Result[String,String]
    try:
        result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    except _: raise Error("unexpected native failure")
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 1)
def check_error_error() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) raises ContextResultRedeemFaultSelected -> String:
        return String(value)
    def cb1(var value: String) raises ContextResultRedeemFaultSelected -> String:
        return value^
    var result: Result[String,String]
    try:
        result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    except _: raise Error("unexpected native failure")
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 0)
def check_error_error_captured() raises:
    var calls0 = 0
    var calls1 = 0
    def cb0(var value: Int) raises ContextResultRedeemFaultSelected {mut calls0} -> String:
        calls0 += 1
        return String(value)
    def cb1(var value: String) raises ContextResultRedeemFaultSelected {mut calls1} -> String:
        calls1 += 1
        return value^
    var result: Result[String,String]
    try:
        result = pipeline(Result[Int,String](Ok(3))).raising[ContextResultRedeemFaultSelected]().redeem(cb0, cb1).get()
    except _: raise Error("unexpected native failure")
    assert_equal(result._ok().value, "3")
    assert_equal(calls0 + calls1, 1)
def main() raises:
    check_pure_pure()
    check_pure_pure_captured()
    check_pure_never()
    check_pure_never_captured()
    check_pure_error()
    check_pure_error_captured()
    check_never_pure()
    check_never_pure_captured()
    check_never_never()
    check_never_never_captured()
    check_never_error()
    check_never_error_captured()
    check_error_pure()
    check_error_pure_captured()
    check_error_never()
    check_error_never_captured()
    check_error_error()
    check_error_error_captured()
