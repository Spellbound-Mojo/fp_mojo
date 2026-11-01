# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultOrElseIfErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultOrElseIfErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultOrElseIfErrorFault:
    var calls = 0
    def cb(value: String) raises ContextRejectResultOrElseIfErrorOther -> Bool:
        raise ContextRejectResultOrElseIfErrorOther(1)
    def second(var value: String) -> Result[Int,String]: return Ok(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultOrElseIfErrorFault]().or_else_if(cb, second).get()
