# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatMapInputCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatMapInputCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatMapInputCapturedFault:
    var calls = 0
    def cb(var value: Bool) raises ContextRejectResultFlatMapInputCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFlatMapInputCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatMapInputCapturedFault]().flat_map(cb).get()
