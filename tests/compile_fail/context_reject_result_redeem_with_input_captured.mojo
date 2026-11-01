# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRedeemWithInputCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRedeemWithInputCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultRedeemWithInputCapturedFault:
    var calls = 0
    def cb(var value: Bool) raises ContextRejectResultRedeemWithInputCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultRedeemWithInputCapturedFault(1)
    def second(var value: String) -> Result[Int,String]: return Ok(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRedeemWithInputCapturedFault]().redeem_with(cb, second).get()
