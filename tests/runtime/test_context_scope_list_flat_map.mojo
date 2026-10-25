from fp.functions import pipeline
from fp.data import Result, Ok
from std.testing import assert_equal
@fieldwise_init
struct ContextScopeListFlatMapFault(Movable):
    var code: Int
def check_pure() raises:
    var calls=0
    def callback(var value: Int) -> List[Int]:
        return List[Int]([value + 1])
    var result: List[Int]
    result = pipeline(List[Int]([2,3])).raising[ContextScopeListFlatMapFault]().flat_map(callback).get()
    assert_equal(result[0], 3)
    assert_equal(calls, 0)
def check_pure_captured() raises:
    var calls=0
    def callback(var value: Int) {mut calls} -> List[Int]:
        calls += 1
        return List[Int]([value + 1])
    var result: List[Int]
    result = pipeline(List[Int]([2,3])).raising[ContextScopeListFlatMapFault]().flat_map(callback).get()
    assert_equal(result[0], 3)
    assert_equal(calls, 2)
def check_never() raises:
    var calls=0
    def callback(var value: Int) raises Never -> List[Int]:
        return List[Int]([value + 1])
    var result: List[Int]
    result = pipeline(List[Int]([2,3])).raising[ContextScopeListFlatMapFault]().flat_map(callback).get()
    assert_equal(result[0], 3)
    assert_equal(calls, 0)
def check_never_captured() raises:
    var calls=0
    def callback(var value: Int) raises Never {mut calls} -> List[Int]:
        calls += 1
        return List[Int]([value + 1])
    var result: List[Int]
    result = pipeline(List[Int]([2,3])).raising[ContextScopeListFlatMapFault]().flat_map(callback).get()
    assert_equal(result[0], 3)
    assert_equal(calls, 2)
def check_raising() raises:
    var calls=0
    def callback(var value: Int) raises ContextScopeListFlatMapFault -> List[Int]:
        return List[Int]([value + 1])
    var result: List[Int]
    try:
        result = pipeline(List[Int]([2,3])).raising[ContextScopeListFlatMapFault]().flat_map(callback).get()
    except _: raise Error("unexpected native error")
    assert_equal(result[0], 3)
    assert_equal(calls, 0)
def check_raising_captured() raises:
    var calls=0
    def callback(var value: Int) raises ContextScopeListFlatMapFault {mut calls} -> List[Int]:
        calls += 1
        return List[Int]([value + 1])
    var result: List[Int]
    try:
        result = pipeline(List[Int]([2,3])).raising[ContextScopeListFlatMapFault]().flat_map(callback).get()
    except _: raise Error("unexpected native error")
    assert_equal(result[0], 3)
    assert_equal(calls, 2)
def main() raises:
    check_pure()
    check_pure_captured()
    check_never()
    check_never_captured()
    check_raising()
    check_raising_captured()
