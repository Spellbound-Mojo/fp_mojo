# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultAttemptTapArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultAttemptTapArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultAttemptTapArityFault:
    var calls = 0
    def cb(value: Result[Int,String], extra: Int) raises ContextRejectResultAttemptTapArityFault -> Result[Int,String]:
        raise ContextRejectResultAttemptTapArityFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultAttemptTapArityFault]().attempt_tap(cb).get()
