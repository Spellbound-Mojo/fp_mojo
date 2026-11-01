# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapBothInputCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapBothInputCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapBothInputCapturedFault:
    var calls = 0
    def cb(var value: Bool) raises ContextRejectResultMapBothInputCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultMapBothInputCapturedFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapBothInputCapturedFault]().map_both(cb, second).get()
