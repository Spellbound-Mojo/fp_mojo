# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultAttemptTapConventionCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultAttemptTapConventionCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultAttemptTapConventionCapturedFault:
    var calls = 0
    def cb(mut value: Result[Int,String]) raises ContextRejectResultAttemptTapConventionCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultAttemptTapConventionCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultAttemptTapConventionCapturedFault]().attempt_tap(cb).get()
