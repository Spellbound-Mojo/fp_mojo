# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultTapErrArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultTapErrArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultTapErrArityCapturedFault:
    var calls = 0
    def cb(value: String, extra: Int) raises ContextRejectResultTapErrArityCapturedFault {mut calls} -> Int:
        calls += 1
        raise ContextRejectResultTapErrArityCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultTapErrArityCapturedFault]().tap_err(cb).get()
