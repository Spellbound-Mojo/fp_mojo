# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatTapInputCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatTapInputCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatTapInputCapturedFault:
    var calls = 0
    def cb(value: Bool) raises ContextRejectResultFlatTapInputCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFlatTapInputCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatTapInputCapturedFault]().flat_tap(cb).get()
