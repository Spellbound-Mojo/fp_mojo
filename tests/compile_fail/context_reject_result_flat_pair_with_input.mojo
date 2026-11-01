# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatPairWithInputFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatPairWithInputOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatPairWithInputFault:
    var calls = 0
    def cb(value: Bool) raises ContextRejectResultFlatPairWithInputFault -> Result[Int,String]:
        raise ContextRejectResultFlatPairWithInputFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatPairWithInputFault]().flat_pair_with(cb).get()
