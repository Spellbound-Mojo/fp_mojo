# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultOrElseConventionCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultOrElseConventionCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultOrElseConventionCapturedFault:
    var calls = 0
    def cb(mut value: String) raises ContextRejectResultOrElseConventionCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultOrElseConventionCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultOrElseConventionCapturedFault]().or_else(cb).get()
