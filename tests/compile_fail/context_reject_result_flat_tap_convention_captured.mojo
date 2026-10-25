# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatTapConventionCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatTapConventionCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatTapConventionCapturedFault:
    var calls = 0
    def cb(mut value: Int) raises ContextRejectResultFlatTapConventionCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFlatTapConventionCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatTapConventionCapturedFault]().flat_tap(cb).get()
