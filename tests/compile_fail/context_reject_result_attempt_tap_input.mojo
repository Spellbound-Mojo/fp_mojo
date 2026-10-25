# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultAttemptTapInputFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultAttemptTapInputOther(Movable):
    var code:Int
def main() raises ContextRejectResultAttemptTapInputFault:
    var calls = 0
    def cb(value: Bool) raises ContextRejectResultAttemptTapInputFault -> Result[Int,String]:
        raise ContextRejectResultAttemptTapInputFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultAttemptTapInputFault]().attempt_tap(cb).get()
