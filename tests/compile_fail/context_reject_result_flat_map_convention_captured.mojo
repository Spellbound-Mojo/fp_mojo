# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatMapConventionCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatMapConventionCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatMapConventionCapturedFault:
    var calls = 0
    def cb(mut value: Int) raises ContextRejectResultFlatMapConventionCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFlatMapConventionCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatMapConventionCapturedFault]().flat_map(cb).get()
