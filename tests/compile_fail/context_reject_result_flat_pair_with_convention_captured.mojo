# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatPairWithConventionCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatPairWithConventionCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatPairWithConventionCapturedFault:
    var calls = 0
    def cb(mut value: Int) raises ContextRejectResultFlatPairWithConventionCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFlatPairWithConventionCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatPairWithConventionCapturedFault]().flat_pair_with(cb).get()
