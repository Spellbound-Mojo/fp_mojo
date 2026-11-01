# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatMapInputFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatMapInputOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatMapInputFault:
    var calls = 0
    def cb(var value: Bool) raises ContextRejectResultFlatMapInputFault -> Result[Int,String]:
        raise ContextRejectResultFlatMapInputFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatMapInputFault]().flat_map(cb).get()
