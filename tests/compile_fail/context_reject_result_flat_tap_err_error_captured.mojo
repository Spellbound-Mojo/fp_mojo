# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatTapErrErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatTapErrErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatTapErrErrorCapturedFault:
    var calls = 0
    def cb(value: String) raises ContextRejectResultFlatTapErrErrorCapturedOther {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFlatTapErrErrorCapturedOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatTapErrErrorCapturedFault]().flat_tap_err(cb).get()
