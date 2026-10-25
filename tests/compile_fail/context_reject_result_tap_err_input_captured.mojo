# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultTapErrInputCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultTapErrInputCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultTapErrInputCapturedFault:
    var calls = 0
    def cb(value: Bool) raises ContextRejectResultTapErrInputCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultTapErrInputCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultTapErrInputCapturedFault]().tap_err(cb).get()
