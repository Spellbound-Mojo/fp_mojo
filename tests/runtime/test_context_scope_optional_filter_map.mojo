from fp.functions import pipeline
from fp.data import Result, Ok
from std.testing import assert_equal
@fieldwise_init
struct ContextScopeOptionalFilterMapFault(Movable):
    var code: Int
def check_pure() raises:
    var calls=0
    def callback(var value: Int) -> Optional[Int]:
        return Optional(value + 1)
    var result: Optional[Int]
    result = pipeline(Optional(2)).raising[ContextScopeOptionalFilterMapFault]().filter_map(callback).get()
    assert_equal(result.take(), 3)
    assert_equal(calls, 0)
def check_pure_captured() raises:
    var calls=0
    def callback(var value: Int) {mut calls} -> Optional[Int]:
        calls += 1
        return Optional(value + 1)
    var result: Optional[Int]
    result = pipeline(Optional(2)).raising[ContextScopeOptionalFilterMapFault]().filter_map(callback).get()
    assert_equal(result.take(), 3)
    assert_equal(calls, 1)
def check_never() raises:
    var calls=0
    def callback(var value: Int) raises Never -> Optional[Int]:
        return Optional(value + 1)
    var result: Optional[Int]
    result = pipeline(Optional(2)).raising[ContextScopeOptionalFilterMapFault]().filter_map(callback).get()
    assert_equal(result.take(), 3)
    assert_equal(calls, 0)
def check_never_captured() raises:
    var calls=0
    def callback(var value: Int) raises Never {mut calls} -> Optional[Int]:
        calls += 1
        return Optional(value + 1)
    var result: Optional[Int]
    result = pipeline(Optional(2)).raising[ContextScopeOptionalFilterMapFault]().filter_map(callback).get()
    assert_equal(result.take(), 3)
    assert_equal(calls, 1)
def check_raising() raises:
    var calls=0
    def callback(var value: Int) raises ContextScopeOptionalFilterMapFault -> Optional[Int]:
        return Optional(value + 1)
    var result: Optional[Int]
    try:
        result = pipeline(Optional(2)).raising[ContextScopeOptionalFilterMapFault]().filter_map(callback).get()
    except _: raise Error("unexpected native error")
    assert_equal(result.take(), 3)
    assert_equal(calls, 0)
def check_raising_captured() raises:
    var calls=0
    def callback(var value: Int) raises ContextScopeOptionalFilterMapFault {mut calls} -> Optional[Int]:
        calls += 1
        return Optional(value + 1)
    var result: Optional[Int]
    try:
        result = pipeline(Optional(2)).raising[ContextScopeOptionalFilterMapFault]().filter_map(callback).get()
    except _: raise Error("unexpected native error")
    assert_equal(result.take(), 3)
    assert_equal(calls, 1)
def main() raises:
    check_pure()
    check_pure_captured()
    check_never()
    check_never_captured()
    check_raising()
    check_raising_captured()
