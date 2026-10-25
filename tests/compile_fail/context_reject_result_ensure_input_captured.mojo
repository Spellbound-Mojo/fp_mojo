# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultEnsureInputCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultEnsureInputCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultEnsureInputCapturedFault:
    var calls = 0
    def cb(value: Bool) raises ContextRejectResultEnsureInputCapturedFault {mut calls} -> Bool:
        calls += 1
        raise ContextRejectResultEnsureInputCapturedFault(1)
    def second(value: Int) -> String: return String("err")
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultEnsureInputCapturedFault]().ensure(cb, second).get()
