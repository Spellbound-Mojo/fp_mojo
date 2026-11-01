# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatMapErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatMapErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatMapErrorFault:
    var calls = 0
    def cb(var value: Int) raises ContextRejectResultFlatMapErrorOther -> Result[Int,String]:
        raise ContextRejectResultFlatMapErrorOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatMapErrorFault]().flat_map(cb).get()
