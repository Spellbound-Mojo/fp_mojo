# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapArityCapturedFault:
    var calls = 0
    def cb(var value: Int, extra: Int) raises ContextRejectResultMapArityCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultMapArityCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapArityCapturedFault]().map(cb).get()
