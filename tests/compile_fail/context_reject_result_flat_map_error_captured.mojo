# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatMapErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatMapErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatMapErrorCapturedFault:
    var calls = 0
    def cb(var value: Int) raises ContextRejectResultFlatMapErrorCapturedOther {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFlatMapErrorCapturedOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatMapErrorCapturedFault]().flat_map(cb).get()
