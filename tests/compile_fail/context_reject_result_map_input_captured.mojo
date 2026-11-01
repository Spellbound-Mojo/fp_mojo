# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapInputCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapInputCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapInputCapturedFault:
    var calls = 0
    def cb(var value: Bool) raises ContextRejectResultMapInputCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultMapInputCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapInputCapturedFault]().map(cb).get()
