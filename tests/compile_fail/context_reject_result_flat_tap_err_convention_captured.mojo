# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatTapErrConventionCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatTapErrConventionCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatTapErrConventionCapturedFault:
    var calls = 0
    def cb(mut value: String) raises ContextRejectResultFlatTapErrConventionCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFlatTapErrConventionCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatTapErrConventionCapturedFault]().flat_tap_err(cb).get()
