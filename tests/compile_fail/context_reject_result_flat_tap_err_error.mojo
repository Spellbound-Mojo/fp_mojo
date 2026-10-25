# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatTapErrErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatTapErrErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatTapErrErrorFault:
    var calls = 0
    def cb(value: String) raises ContextRejectResultFlatTapErrErrorOther -> Result[Int,String]:
        raise ContextRejectResultFlatTapErrErrorOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatTapErrErrorFault]().flat_tap_err(cb).get()
