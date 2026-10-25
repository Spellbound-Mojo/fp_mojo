# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatPairWithConventionFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatPairWithConventionOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatPairWithConventionFault:
    var calls = 0
    def cb(mut value: Int) raises ContextRejectResultFlatPairWithConventionFault -> Result[Int,String]:
        raise ContextRejectResultFlatPairWithConventionFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatPairWithConventionFault]().flat_pair_with(cb).get()
