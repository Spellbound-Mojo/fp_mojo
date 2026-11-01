# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapArityFault:
    var calls = 0
    def cb(var value: Int, extra: Int) raises ContextRejectResultMapArityFault -> Int:
        raise ContextRejectResultMapArityFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapArityFault]().map(cb).get()
