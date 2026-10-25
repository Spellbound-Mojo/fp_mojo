# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRedeemArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRedeemArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultRedeemArityCapturedFault:
    var calls = 0
    def cb(var value: Int, extra: Int) raises ContextRejectResultRedeemArityCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultRedeemArityCapturedFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRedeemArityCapturedFault]().redeem(cb, second).get()
