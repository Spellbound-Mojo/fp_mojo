# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatTapErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatTapErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatTapErrorCapturedFault:
    var calls = 0
    def cb(value: Int) raises ContextRejectResultFlatTapErrorCapturedOther {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFlatTapErrorCapturedOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatTapErrorCapturedFault]().flat_tap(cb).get()
