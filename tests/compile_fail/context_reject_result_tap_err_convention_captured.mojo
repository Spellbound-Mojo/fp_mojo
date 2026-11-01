# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultTapErrConventionCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultTapErrConventionCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultTapErrConventionCapturedFault:
    var calls = 0
    def cb(mut value: String) raises ContextRejectResultTapErrConventionCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultTapErrConventionCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultTapErrConventionCapturedFault]().tap_err(cb).get()
