# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRecoverIfArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRecoverIfArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultRecoverIfArityCapturedFault:
    var calls = 0
    def cb(value: String, extra: Int) raises ContextRejectResultRecoverIfArityCapturedFault {mut calls} -> Bool:
        calls += 1
        raise ContextRejectResultRecoverIfArityCapturedFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRecoverIfArityCapturedFault]().recover_if(cb, second).get()
