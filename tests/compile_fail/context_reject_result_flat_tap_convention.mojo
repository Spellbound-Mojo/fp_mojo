# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatTapConventionFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatTapConventionOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatTapConventionFault:
    var calls = 0
    def cb(mut value: Int) raises ContextRejectResultFlatTapConventionFault -> Result[Int,String]:
        raise ContextRejectResultFlatTapConventionFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatTapConventionFault]().flat_tap(cb).get()
