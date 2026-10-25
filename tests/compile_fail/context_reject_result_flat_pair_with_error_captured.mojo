# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatPairWithErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatPairWithErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatPairWithErrorCapturedFault:
    var calls = 0
    def cb(value: Int) raises ContextRejectResultFlatPairWithErrorCapturedOther {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFlatPairWithErrorCapturedOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatPairWithErrorCapturedFault]().flat_pair_with(cb).get()
