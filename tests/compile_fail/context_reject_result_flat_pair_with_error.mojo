# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatPairWithErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatPairWithErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatPairWithErrorFault:
    var calls = 0
    def cb(value: Int) raises ContextRejectResultFlatPairWithErrorOther -> Result[Int,String]:
        raise ContextRejectResultFlatPairWithErrorOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatPairWithErrorFault]().flat_pair_with(cb).get()
