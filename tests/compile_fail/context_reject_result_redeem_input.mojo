# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRedeemInputFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRedeemInputOther(Movable):
    var code:Int
def main() raises ContextRejectResultRedeemInputFault:
    var calls = 0
    def cb(var value: Bool) raises ContextRejectResultRedeemInputFault -> Int:
        raise ContextRejectResultRedeemInputFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRedeemInputFault]().redeem(cb, second).get()
