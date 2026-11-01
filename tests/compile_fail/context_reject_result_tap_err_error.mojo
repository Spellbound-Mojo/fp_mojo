# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultTapErrErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultTapErrErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultTapErrErrorFault:
    var calls = 0
    def cb(value: String) raises ContextRejectResultTapErrErrorOther -> Int:
        raise ContextRejectResultTapErrErrorOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultTapErrErrorFault]().tap_err(cb).get()
