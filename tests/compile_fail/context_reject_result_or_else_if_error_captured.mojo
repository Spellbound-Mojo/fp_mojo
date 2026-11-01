# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultOrElseIfErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultOrElseIfErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultOrElseIfErrorCapturedFault:
    var calls = 0
    def cb(value: String) raises ContextRejectResultOrElseIfErrorCapturedOther {mut calls} -> Bool:
        calls += 1
        raise ContextRejectResultOrElseIfErrorCapturedOther(1)
    def second(var value: String) -> Result[Int,String]: return Ok(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultOrElseIfErrorCapturedFault]().or_else_if(cb, second).get()
