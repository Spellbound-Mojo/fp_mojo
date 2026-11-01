# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultEnsureConventionCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultEnsureConventionCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultEnsureConventionCapturedFault:
    var calls = 0
    def cb(mut value: Int) raises ContextRejectResultEnsureConventionCapturedFault {mut calls} -> Bool:
        calls += 1
        raise ContextRejectResultEnsureConventionCapturedFault(1)
    def second(value: Int) -> String: return String("err")
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultEnsureConventionCapturedFault]().ensure(cb, second).get()
