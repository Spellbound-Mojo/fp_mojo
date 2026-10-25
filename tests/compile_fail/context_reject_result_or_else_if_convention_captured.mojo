# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultOrElseIfConventionCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultOrElseIfConventionCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultOrElseIfConventionCapturedFault:
    var calls = 0
    def cb(mut value: String) raises ContextRejectResultOrElseIfConventionCapturedFault {mut calls} -> Bool:
        calls += 1
        raise ContextRejectResultOrElseIfConventionCapturedFault(1)
    def second(var value: String) -> Result[Int,String]: return Ok(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultOrElseIfConventionCapturedFault]().or_else_if(cb, second).get()
