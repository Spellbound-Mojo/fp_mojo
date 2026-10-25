from fp.functions import pipeline
from fp.data import Result, Ok
from std.testing import assert_equal
@fieldwise_init
struct ContextScopeResultMapFault(Movable):
    var code: Int
def check_pure() raises:
    var calls=0
    def callback(var value: Int) -> Int:
        return value + 1
    var result: Result[Int,String]
    result = pipeline(Result[Int,String](Ok(2))).raising[ContextScopeResultMapFault]().map(callback).get()
    assert_equal(result._ok().value, 3)
    assert_equal(calls, 0)
def check_pure_captured() raises:
    var calls=0
    def callback(var value: Int) {mut calls} -> Int:
        calls += 1
        return value + 1
    var result: Result[Int,String]
    result = pipeline(Result[Int,String](Ok(2))).raising[ContextScopeResultMapFault]().map(callback).get()
    assert_equal(result._ok().value, 3)
    assert_equal(calls, 1)
def check_never() raises:
    var calls=0
    def callback(var value: Int) raises Never -> Int:
        return value + 1
    var result: Result[Int,String]
    result = pipeline(Result[Int,String](Ok(2))).raising[ContextScopeResultMapFault]().map(callback).get()
    assert_equal(result._ok().value, 3)
    assert_equal(calls, 0)
def check_never_captured() raises:
    var calls=0
    def callback(var value: Int) raises Never {mut calls} -> Int:
        calls += 1
        return value + 1
    var result: Result[Int,String]
    result = pipeline(Result[Int,String](Ok(2))).raising[ContextScopeResultMapFault]().map(callback).get()
    assert_equal(result._ok().value, 3)
    assert_equal(calls, 1)
def check_raising() raises:
    var calls=0
    def callback(var value: Int) raises ContextScopeResultMapFault -> Int:
        return value + 1
    var result: Result[Int,String]
    try:
        result = pipeline(Result[Int,String](Ok(2))).raising[ContextScopeResultMapFault]().map(callback).get()
    except _: raise Error("unexpected native error")
    assert_equal(result._ok().value, 3)
    assert_equal(calls, 0)
def check_raising_captured() raises:
    var calls=0
    def callback(var value: Int) raises ContextScopeResultMapFault {mut calls} -> Int:
        calls += 1
        return value + 1
    var result: Result[Int,String]
    try:
        result = pipeline(Result[Int,String](Ok(2))).raising[ContextScopeResultMapFault]().map(callback).get()
    except _: raise Error("unexpected native error")
    assert_equal(result._ok().value, 3)
    assert_equal(calls, 1)
def main() raises:
    check_pure()
    check_pure_captured()
    check_never()
    check_never_captured()
    check_raising()
    check_raising_captured()
