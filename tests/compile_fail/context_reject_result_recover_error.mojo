# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRecoverErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRecoverErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultRecoverErrorFault:
    var calls = 0
    def cb(var value: String) raises ContextRejectResultRecoverErrorOther -> Int:
        raise ContextRejectResultRecoverErrorOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRecoverErrorFault]().recover(cb).get()
