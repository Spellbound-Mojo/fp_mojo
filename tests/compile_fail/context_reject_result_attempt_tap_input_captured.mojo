# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultAttemptTapInputCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultAttemptTapInputCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultAttemptTapInputCapturedFault:
    var calls = 0
    def cb(value: Bool) raises ContextRejectResultAttemptTapInputCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultAttemptTapInputCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultAttemptTapInputCapturedFault]().attempt_tap(cb).get()
