# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatTapErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatTapErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatTapErrorFault:
    var calls = 0
    def cb(value: Int) raises ContextRejectResultFlatTapErrorOther -> Result[Int,String]:
        raise ContextRejectResultFlatTapErrorOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatTapErrorFault]().flat_tap(cb).get()
