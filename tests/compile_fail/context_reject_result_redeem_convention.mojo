# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRedeemConventionFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRedeemConventionOther(Movable):
    var code:Int
def main() raises ContextRejectResultRedeemConventionFault:
    var calls = 0
    def cb(mut value: Int) raises ContextRejectResultRedeemConventionFault -> Int:
        raise ContextRejectResultRedeemConventionFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRedeemConventionFault]().redeem(cb, second).get()
