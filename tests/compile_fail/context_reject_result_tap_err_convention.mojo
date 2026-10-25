# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultTapErrConventionFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultTapErrConventionOther(Movable):
    var code:Int
def main() raises ContextRejectResultTapErrConventionFault:
    var calls = 0
    def cb(mut value: String) raises ContextRejectResultTapErrConventionFault -> Int:
        raise ContextRejectResultTapErrConventionFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultTapErrConventionFault]().tap_err(cb).get()
