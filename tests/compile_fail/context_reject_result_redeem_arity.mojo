# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRedeemArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRedeemArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultRedeemArityFault:
    var calls = 0
    def cb(var value: Int, extra: Int) raises ContextRejectResultRedeemArityFault -> Int:
        raise ContextRejectResultRedeemArityFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRedeemArityFault]().redeem(cb, second).get()
