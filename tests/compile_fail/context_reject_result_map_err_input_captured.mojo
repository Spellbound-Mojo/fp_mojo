# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapErrInputCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapErrInputCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapErrInputCapturedFault:
    var calls = 0
    def cb(var value: Bool) raises ContextRejectResultMapErrInputCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultMapErrInputCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapErrInputCapturedFault]().map_err(cb).get()
