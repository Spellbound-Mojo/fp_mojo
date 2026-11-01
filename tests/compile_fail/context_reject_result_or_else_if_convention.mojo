# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultOrElseIfConventionFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultOrElseIfConventionOther(Movable):
    var code:Int
def main() raises ContextRejectResultOrElseIfConventionFault:
    var calls = 0
    def cb(mut value: String) raises ContextRejectResultOrElseIfConventionFault -> Bool:
        raise ContextRejectResultOrElseIfConventionFault(1)
    def second(var value: String) -> Result[Int,String]: return Ok(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultOrElseIfConventionFault]().or_else_if(cb, second).get()
