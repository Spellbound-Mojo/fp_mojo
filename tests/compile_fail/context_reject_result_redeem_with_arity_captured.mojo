# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRedeemWithArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRedeemWithArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultRedeemWithArityCapturedFault:
    var calls = 0
    def cb(var value: Int, extra: Int) raises ContextRejectResultRedeemWithArityCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultRedeemWithArityCapturedFault(1)
    def second(var value: String) -> Result[Int,String]: return Ok(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRedeemWithArityCapturedFault]().redeem_with(cb, second).get()
