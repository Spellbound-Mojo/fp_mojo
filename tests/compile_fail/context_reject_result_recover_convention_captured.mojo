# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRecoverConventionCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRecoverConventionCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultRecoverConventionCapturedFault:
    var calls = 0
    def cb(mut value: String) raises ContextRejectResultRecoverConventionCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultRecoverConventionCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRecoverConventionCapturedFault]().recover(cb).get()
