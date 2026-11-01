# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatMapArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatMapArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatMapArityFault:
    var calls = 0
    def cb(var value: Int, extra: Int) raises ContextRejectResultFlatMapArityFault -> Result[Int,String]:
        raise ContextRejectResultFlatMapArityFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatMapArityFault]().flat_map(cb).get()
