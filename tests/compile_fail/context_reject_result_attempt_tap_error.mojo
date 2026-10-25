# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultAttemptTapErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultAttemptTapErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultAttemptTapErrorFault:
    var calls = 0
    def cb(value: Result[Int,String]) raises ContextRejectResultAttemptTapErrorOther -> Result[Int,String]:
        raise ContextRejectResultAttemptTapErrorOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultAttemptTapErrorFault]().attempt_tap(cb).get()
