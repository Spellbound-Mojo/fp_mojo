# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultBeforeErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultBeforeErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultBeforeErrorCapturedFault:
    var calls = 0
    def cb() raises ContextRejectResultBeforeErrorCapturedOther {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultBeforeErrorCapturedOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultBeforeErrorCapturedFault]().before(cb).get()
