# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultAttemptTapConventionFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultAttemptTapConventionOther(Movable):
    var code:Int
def main() raises ContextRejectResultAttemptTapConventionFault:
    var calls = 0
    def cb(mut value: Result[Int,String]) raises ContextRejectResultAttemptTapConventionFault -> Result[Int,String]:
        raise ContextRejectResultAttemptTapConventionFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultAttemptTapConventionFault]().attempt_tap(cb).get()
