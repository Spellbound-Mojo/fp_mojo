# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRedeemWithConventionCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRedeemWithConventionCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultRedeemWithConventionCapturedFault:
    var calls = 0
    def cb(mut value: Int) raises ContextRejectResultRedeemWithConventionCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultRedeemWithConventionCapturedFault(1)
    def second(var value: String) -> Result[Int,String]: return Ok(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRedeemWithConventionCapturedFault]().redeem_with(cb, second).get()
