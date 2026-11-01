# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultTapErrArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultTapErrArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultTapErrArityFault:
    var calls = 0
    def cb(value: String, extra: Int) raises ContextRejectResultTapErrArityFault -> Int:
        raise ContextRejectResultTapErrArityFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultTapErrArityFault]().tap_err(cb).get()
