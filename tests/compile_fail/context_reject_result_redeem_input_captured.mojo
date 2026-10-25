# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRedeemInputCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRedeemInputCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultRedeemInputCapturedFault:
    var calls = 0
    def cb(var value: Bool) raises ContextRejectResultRedeemInputCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultRedeemInputCapturedFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRedeemInputCapturedFault]().redeem(cb, second).get()
