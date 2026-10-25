# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatMapConventionFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatMapConventionOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatMapConventionFault:
    var calls = 0
    def cb(mut value: Int) raises ContextRejectResultFlatMapConventionFault -> Result[Int,String]:
        raise ContextRejectResultFlatMapConventionFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatMapConventionFault]().flat_map(cb).get()
