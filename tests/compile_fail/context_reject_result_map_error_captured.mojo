# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapErrorCapturedFault:
    var calls = 0
    def cb(var value: Int) raises ContextRejectResultMapErrorCapturedOther {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultMapErrorCapturedOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapErrorCapturedFault]().map(cb).get()
