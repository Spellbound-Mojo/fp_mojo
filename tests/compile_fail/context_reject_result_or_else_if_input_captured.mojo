# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultOrElseIfInputCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultOrElseIfInputCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultOrElseIfInputCapturedFault:
    var calls = 0
    def cb(value: Bool) raises ContextRejectResultOrElseIfInputCapturedFault {mut calls} -> Bool:
        calls += 1
        raise ContextRejectResultOrElseIfInputCapturedFault(1)
    def second(var value: String) -> Result[Int,String]: return Ok(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultOrElseIfInputCapturedFault]().or_else_if(cb, second).get()
