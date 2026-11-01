# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultBeforeArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultBeforeArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultBeforeArityCapturedFault:
    var calls = 0
    def cb(extra: Int) raises ContextRejectResultBeforeArityCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultBeforeArityCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultBeforeArityCapturedFault]().before(cb).get()
