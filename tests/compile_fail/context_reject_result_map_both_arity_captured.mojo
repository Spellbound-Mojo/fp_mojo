# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapBothArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapBothArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapBothArityCapturedFault:
    var calls = 0
    def cb(var value: Int, extra: Int) raises ContextRejectResultMapBothArityCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultMapBothArityCapturedFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapBothArityCapturedFault]().map_both(cb, second).get()
