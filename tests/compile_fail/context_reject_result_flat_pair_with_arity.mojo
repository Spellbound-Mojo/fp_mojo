# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatPairWithArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatPairWithArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatPairWithArityFault:
    var calls = 0
    def cb(value: Int, extra: Int) raises ContextRejectResultFlatPairWithArityFault -> Result[Int,String]:
        raise ContextRejectResultFlatPairWithArityFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatPairWithArityFault]().flat_pair_with(cb).get()
