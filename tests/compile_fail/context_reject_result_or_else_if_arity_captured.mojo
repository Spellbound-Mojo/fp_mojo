# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultOrElseIfArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultOrElseIfArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultOrElseIfArityCapturedFault:
    var calls = 0
    def cb(value: String, extra: Int) raises ContextRejectResultOrElseIfArityCapturedFault {mut calls} -> Bool:
        calls += 1
        raise ContextRejectResultOrElseIfArityCapturedFault(1)
    def second(var value: String) -> Result[Int,String]: return Ok(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultOrElseIfArityCapturedFault]().or_else_if(cb, second).get()
