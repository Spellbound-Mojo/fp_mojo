# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatTapErrInputCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatTapErrInputCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatTapErrInputCapturedFault:
    var calls = 0
    def cb(value: Bool) raises ContextRejectResultFlatTapErrInputCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFlatTapErrInputCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatTapErrInputCapturedFault]().flat_tap_err(cb).get()
