# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultTapErrErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultTapErrErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultTapErrErrorCapturedFault:
    var calls = 0
    def cb(value: String) raises ContextRejectResultTapErrErrorCapturedOther {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultTapErrErrorCapturedOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultTapErrErrorCapturedFault]().tap_err(cb).get()
