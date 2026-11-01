# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRedeemErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRedeemErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultRedeemErrorCapturedFault:
    var calls = 0
    def cb(var value: Int) raises ContextRejectResultRedeemErrorCapturedOther {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultRedeemErrorCapturedOther(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRedeemErrorCapturedFault]().redeem(cb, second).get()
