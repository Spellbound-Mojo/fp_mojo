# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatTapArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatTapArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatTapArityCapturedFault:
    var calls = 0
    def cb(value: Int, extra: Int) raises ContextRejectResultFlatTapArityCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFlatTapArityCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatTapArityCapturedFault]().flat_tap(cb).get()
