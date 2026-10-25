# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultOrElseIfInputFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultOrElseIfInputOther(Movable):
    var code:Int
def main() raises ContextRejectResultOrElseIfInputFault:
    var calls = 0
    def cb(value: Bool) raises ContextRejectResultOrElseIfInputFault -> Bool:
        raise ContextRejectResultOrElseIfInputFault(1)
    def second(var value: String) -> Result[Int,String]: return Ok(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultOrElseIfInputFault]().or_else_if(cb, second).get()
