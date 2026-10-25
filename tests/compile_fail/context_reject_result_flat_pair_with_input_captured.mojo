# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatPairWithInputCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatPairWithInputCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatPairWithInputCapturedFault:
    var calls = 0
    def cb(value: Bool) raises ContextRejectResultFlatPairWithInputCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFlatPairWithInputCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatPairWithInputCapturedFault]().flat_pair_with(cb).get()
