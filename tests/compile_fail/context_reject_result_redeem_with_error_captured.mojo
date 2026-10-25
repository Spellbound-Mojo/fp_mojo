# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRedeemWithErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRedeemWithErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultRedeemWithErrorCapturedFault:
    var calls = 0
    def cb(var value: Int) raises ContextRejectResultRedeemWithErrorCapturedOther {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultRedeemWithErrorCapturedOther(1)
    def second(var value: String) -> Result[Int,String]: return Ok(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRedeemWithErrorCapturedFault]().redeem_with(cb, second).get()
