# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapErrorFault:
    var calls = 0
    def cb(var value: Int) raises ContextRejectResultMapErrorOther -> Int:
        raise ContextRejectResultMapErrorOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapErrorFault]().map(cb).get()
