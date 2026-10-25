# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRecoverArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRecoverArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultRecoverArityCapturedFault:
    var calls = 0
    def cb(var value: String, extra: Int) raises ContextRejectResultRecoverArityCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultRecoverArityCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRecoverArityCapturedFault]().recover(cb).get()
