# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultAttemptTapArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultAttemptTapArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultAttemptTapArityCapturedFault:
    var calls = 0
    def cb(value: Result[Int,String], extra: Int) raises ContextRejectResultAttemptTapArityCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultAttemptTapArityCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultAttemptTapArityCapturedFault]().attempt_tap(cb).get()
