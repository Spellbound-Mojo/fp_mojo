# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatMapArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatMapArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatMapArityCapturedFault:
    var calls = 0
    def cb(var value: Int, extra: Int) raises ContextRejectResultFlatMapArityCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFlatMapArityCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatMapArityCapturedFault]().flat_map(cb).get()
