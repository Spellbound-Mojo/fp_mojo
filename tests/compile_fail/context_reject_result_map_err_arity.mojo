# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapErrArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapErrArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapErrArityFault:
    var calls = 0
    def cb(var value: String, extra: Int) raises ContextRejectResultMapErrArityFault -> Int:
        raise ContextRejectResultMapErrArityFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapErrArityFault]().map_err(cb).get()
