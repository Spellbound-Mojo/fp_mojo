# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapInputFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapInputOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapInputFault:
    var calls = 0
    def cb(var value: Bool) raises ContextRejectResultMapInputFault -> Int:
        raise ContextRejectResultMapInputFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapInputFault]().map(cb).get()
