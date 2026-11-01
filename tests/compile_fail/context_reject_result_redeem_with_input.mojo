# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRedeemWithInputFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRedeemWithInputOther(Movable):
    var code:Int
def main() raises ContextRejectResultRedeemWithInputFault:
    var calls = 0
    def cb(var value: Bool) raises ContextRejectResultRedeemWithInputFault -> Result[Int,String]:
        raise ContextRejectResultRedeemWithInputFault(1)
    def second(var value: String) -> Result[Int,String]: return Ok(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRedeemWithInputFault]().redeem_with(cb, second).get()
