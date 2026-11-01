# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatTapErrConventionFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatTapErrConventionOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatTapErrConventionFault:
    var calls = 0
    def cb(mut value: String) raises ContextRejectResultFlatTapErrConventionFault -> Result[Int,String]:
        raise ContextRejectResultFlatTapErrConventionFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatTapErrConventionFault]().flat_tap_err(cb).get()
