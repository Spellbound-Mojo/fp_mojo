# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapBothConventionCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapBothConventionCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapBothConventionCapturedFault:
    var calls = 0
    def cb(mut value: Int) raises ContextRejectResultMapBothConventionCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultMapBothConventionCapturedFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapBothConventionCapturedFault]().map_both(cb, second).get()
