# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultOrElseErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultOrElseErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultOrElseErrorFault:
    var calls = 0
    def cb(var value: String) raises ContextRejectResultOrElseErrorOther -> Result[Int,String]:
        raise ContextRejectResultOrElseErrorOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultOrElseErrorFault]().or_else(cb).get()
