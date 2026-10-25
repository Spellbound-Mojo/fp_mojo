# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRedeemWithConventionFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRedeemWithConventionOther(Movable):
    var code:Int
def main() raises ContextRejectResultRedeemWithConventionFault:
    var calls = 0
    def cb(mut value: Int) raises ContextRejectResultRedeemWithConventionFault -> Result[Int,String]:
        raise ContextRejectResultRedeemWithConventionFault(1)
    def second(var value: String) -> Result[Int,String]: return Ok(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRedeemWithConventionFault]().redeem_with(cb, second).get()
