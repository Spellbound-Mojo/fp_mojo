# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapBothErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapBothErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapBothErrorCapturedFault:
    var calls = 0
    def cb(var value: Int) raises ContextRejectResultMapBothErrorCapturedOther {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultMapBothErrorCapturedOther(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapBothErrorCapturedFault]().map_both(cb, second).get()
