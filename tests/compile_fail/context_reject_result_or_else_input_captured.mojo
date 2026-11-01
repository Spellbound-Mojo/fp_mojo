# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultOrElseInputCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultOrElseInputCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultOrElseInputCapturedFault:
    var calls = 0
    def cb(var value: Bool) raises ContextRejectResultOrElseInputCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultOrElseInputCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultOrElseInputCapturedFault]().or_else(cb).get()
