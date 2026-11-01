# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultEnsureArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultEnsureArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultEnsureArityCapturedFault:
    var calls = 0
    def cb(value: Int, extra: Int) raises ContextRejectResultEnsureArityCapturedFault {mut calls} -> Bool:
        calls += 1
        raise ContextRejectResultEnsureArityCapturedFault(1)
    def second(value: Int) -> String: return String("err")
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultEnsureArityCapturedFault]().ensure(cb, second).get()
