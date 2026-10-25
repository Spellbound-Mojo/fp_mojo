# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRedeemWithErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRedeemWithErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultRedeemWithErrorFault:
    var calls = 0
    def cb(var value: Int) raises ContextRejectResultRedeemWithErrorOther -> Result[Int,String]:
        raise ContextRejectResultRedeemWithErrorOther(1)
    def second(var value: String) -> Result[Int,String]: return Ok(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRedeemWithErrorFault]().redeem_with(cb, second).get()
