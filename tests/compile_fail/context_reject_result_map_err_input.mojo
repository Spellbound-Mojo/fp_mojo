# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapErrInputFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapErrInputOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapErrInputFault:
    var calls = 0
    def cb(var value: Bool) raises ContextRejectResultMapErrInputFault -> Int:
        raise ContextRejectResultMapErrInputFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapErrInputFault]().map_err(cb).get()
