# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapErrErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapErrErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapErrErrorFault:
    var calls = 0
    def cb(var value: String) raises ContextRejectResultMapErrErrorOther -> Int:
        raise ContextRejectResultMapErrErrorOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapErrErrorFault]().map_err(cb).get()
