# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapErrConventionCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapErrConventionCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapErrConventionCapturedFault:
    var calls = 0
    def cb(mut value: String) raises ContextRejectResultMapErrConventionCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultMapErrConventionCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapErrConventionCapturedFault]().map_err(cb).get()
