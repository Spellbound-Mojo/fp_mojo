# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapConventionCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapConventionCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapConventionCapturedFault:
    var calls = 0
    def cb(mut value: Int) raises ContextRejectResultMapConventionCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultMapConventionCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapConventionCapturedFault]().map(cb).get()
