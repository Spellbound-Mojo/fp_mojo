# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRecoverErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRecoverErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultRecoverErrorCapturedFault:
    var calls = 0
    def cb(var value: String) raises ContextRejectResultRecoverErrorCapturedOther {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultRecoverErrorCapturedOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRecoverErrorCapturedFault]().recover(cb).get()
