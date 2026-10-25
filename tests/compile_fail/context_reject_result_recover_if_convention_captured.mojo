# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRecoverIfConventionCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRecoverIfConventionCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultRecoverIfConventionCapturedFault:
    var calls = 0
    def cb(mut value: String) raises ContextRejectResultRecoverIfConventionCapturedFault {mut calls} -> Bool:
        calls += 1
        raise ContextRejectResultRecoverIfConventionCapturedFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRecoverIfConventionCapturedFault]().recover_if(cb, second).get()
