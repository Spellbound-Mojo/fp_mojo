# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRecoverIfErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRecoverIfErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultRecoverIfErrorCapturedFault:
    var calls = 0
    def cb(value: String) raises ContextRejectResultRecoverIfErrorCapturedOther {mut calls} -> Bool:
        calls += 1
        raise ContextRejectResultRecoverIfErrorCapturedOther(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRecoverIfErrorCapturedFault]().recover_if(cb, second).get()
