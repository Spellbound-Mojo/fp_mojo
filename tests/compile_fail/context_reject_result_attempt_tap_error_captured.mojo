# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultAttemptTapErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultAttemptTapErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultAttemptTapErrorCapturedFault:
    var calls = 0
    def cb(value: Result[Int,String]) raises ContextRejectResultAttemptTapErrorCapturedOther {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultAttemptTapErrorCapturedOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultAttemptTapErrorCapturedFault]().attempt_tap(cb).get()
