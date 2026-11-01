# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRedeemErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRedeemErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultRedeemErrorFault:
    var calls = 0
    def cb(var value: Int) raises ContextRejectResultRedeemErrorOther -> Int:
        raise ContextRejectResultRedeemErrorOther(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRedeemErrorFault]().redeem(cb, second).get()
