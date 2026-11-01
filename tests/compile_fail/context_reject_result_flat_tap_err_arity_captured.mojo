# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatTapErrArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatTapErrArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatTapErrArityCapturedFault:
    var calls = 0
    def cb(value: String, extra: Int) raises ContextRejectResultFlatTapErrArityCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFlatTapErrArityCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatTapErrArityCapturedFault]().flat_tap_err(cb).get()
