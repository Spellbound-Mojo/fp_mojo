from fp.functions import pipeline
from fp.data import Result, Ok
from std.testing import assert_equal
@fieldwise_init
struct ContextScopeOptionalFilterFault(Movable):
    var code: Int
def check_pure() raises:
    var calls=0
    def callback(value: Int) -> Bool:
        return value > 1
    var result: Optional[Int]
    result = pipeline(Optional(2)).raising[ContextScopeOptionalFilterFault]().filter(callback).get()
    assert_equal(result.take(), 2)
    assert_equal(calls, 0)
def check_pure_captured() raises:
    var calls=0
    def callback(value: Int) {mut calls} -> Bool:
        calls += 1
        return value > 1
    var result: Optional[Int]
    result = pipeline(Optional(2)).raising[ContextScopeOptionalFilterFault]().filter(callback).get()
    assert_equal(result.take(), 2)
    assert_equal(calls, 1)
def check_never() raises:
    var calls=0
    def callback(value: Int) raises Never -> Bool:
        return value > 1
    var result: Optional[Int]
    result = pipeline(Optional(2)).raising[ContextScopeOptionalFilterFault]().filter(callback).get()
    assert_equal(result.take(), 2)
    assert_equal(calls, 0)
def check_never_captured() raises:
    var calls=0
    def callback(value: Int) raises Never {mut calls} -> Bool:
        calls += 1
        return value > 1
    var result: Optional[Int]
    result = pipeline(Optional(2)).raising[ContextScopeOptionalFilterFault]().filter(callback).get()
    assert_equal(result.take(), 2)
    assert_equal(calls, 1)
def check_raising() raises:
    var calls=0
    def callback(value: Int) raises ContextScopeOptionalFilterFault -> Bool:
        return value > 1
    var result: Optional[Int]
    try:
        result = pipeline(Optional(2)).raising[ContextScopeOptionalFilterFault]().filter(callback).get()
    except _: raise Error("unexpected native error")
    assert_equal(result.take(), 2)
    assert_equal(calls, 0)
def check_raising_captured() raises:
    var calls=0
    def callback(value: Int) raises ContextScopeOptionalFilterFault {mut calls} -> Bool:
        calls += 1
        return value > 1
    var result: Optional[Int]
    try:
        result = pipeline(Optional(2)).raising[ContextScopeOptionalFilterFault]().filter(callback).get()
    except _: raise Error("unexpected native error")
    assert_equal(result.take(), 2)
    assert_equal(calls, 1)
def main() raises:
    check_pure()
    check_pure_captured()
    check_never()
    check_never_captured()
    check_raising()
    check_raising_captured()
