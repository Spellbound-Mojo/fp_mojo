# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRecoverInputCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRecoverInputCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultRecoverInputCapturedFault:
    var calls = 0
    def cb(var value: Bool) raises ContextRejectResultRecoverInputCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultRecoverInputCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRecoverInputCapturedFault]().recover(cb).get()
