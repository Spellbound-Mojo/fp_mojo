# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapErrArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapErrArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapErrArityCapturedFault:
    var calls = 0
    def cb(var value: String, extra: Int) raises ContextRejectResultMapErrArityCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultMapErrArityCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapErrArityCapturedFault]().map_err(cb).get()
