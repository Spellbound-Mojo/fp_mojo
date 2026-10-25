# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRedeemWithArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRedeemWithArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultRedeemWithArityFault:
    var calls = 0
    def cb(var value: Int, extra: Int) raises ContextRejectResultRedeemWithArityFault -> Result[Int,String]:
        raise ContextRejectResultRedeemWithArityFault(1)
    def second(var value: String) -> Result[Int,String]: return Ok(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRedeemWithArityFault]().redeem_with(cb, second).get()
