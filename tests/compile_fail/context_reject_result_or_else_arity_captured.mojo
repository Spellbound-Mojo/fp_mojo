# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultOrElseArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultOrElseArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultOrElseArityCapturedFault:
    var calls = 0
    def cb(var value: String, extra: Int) raises ContextRejectResultOrElseArityCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultOrElseArityCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultOrElseArityCapturedFault]().or_else(cb).get()
