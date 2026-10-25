# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultOrElseIfArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultOrElseIfArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultOrElseIfArityFault:
    var calls = 0
    def cb(value: String, extra: Int) raises ContextRejectResultOrElseIfArityFault -> Bool:
        raise ContextRejectResultOrElseIfArityFault(1)
    def second(var value: String) -> Result[Int,String]: return Ok(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultOrElseIfArityFault]().or_else_if(cb, second).get()
