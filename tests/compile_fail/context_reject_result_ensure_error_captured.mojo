# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultEnsureErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultEnsureErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultEnsureErrorCapturedFault:
    var calls = 0
    def cb(value: Int) raises ContextRejectResultEnsureErrorCapturedOther {mut calls} -> Bool:
        calls += 1
        raise ContextRejectResultEnsureErrorCapturedOther(1)
    def second(value: Int) -> String: return String("err")
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultEnsureErrorCapturedFault]().ensure(cb, second).get()
