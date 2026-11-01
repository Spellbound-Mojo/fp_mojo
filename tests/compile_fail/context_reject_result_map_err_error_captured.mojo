# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapErrErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapErrErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapErrErrorCapturedFault:
    var calls = 0
    def cb(var value: String) raises ContextRejectResultMapErrErrorCapturedOther {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultMapErrErrorCapturedOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapErrErrorCapturedFault]().map_err(cb).get()
