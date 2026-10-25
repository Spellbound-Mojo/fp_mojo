# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRecoverIfInputCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRecoverIfInputCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultRecoverIfInputCapturedFault:
    var calls = 0
    def cb(value: Bool) raises ContextRejectResultRecoverIfInputCapturedFault {mut calls} -> Bool:
        calls += 1
        raise ContextRejectResultRecoverIfInputCapturedFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRecoverIfInputCapturedFault]().recover_if(cb, second).get()
