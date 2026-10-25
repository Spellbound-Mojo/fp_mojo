# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultOrElseErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultOrElseErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultOrElseErrorCapturedFault:
    var calls = 0
    def cb(var value: String) raises ContextRejectResultOrElseErrorCapturedOther {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultOrElseErrorCapturedOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultOrElseErrorCapturedFault]().or_else(cb).get()
