# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatPairWithArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatPairWithArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatPairWithArityCapturedFault:
    var calls = 0
    def cb(value: Int, extra: Int) raises ContextRejectResultFlatPairWithArityCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFlatPairWithArityCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatPairWithArityCapturedFault]().flat_pair_with(cb).get()
