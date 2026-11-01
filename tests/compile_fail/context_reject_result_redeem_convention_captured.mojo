# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRedeemConventionCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRedeemConventionCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultRedeemConventionCapturedFault:
    var calls = 0
    def cb(mut value: Int) raises ContextRejectResultRedeemConventionCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultRedeemConventionCapturedFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRedeemConventionCapturedFault]().redeem(cb, second).get()
