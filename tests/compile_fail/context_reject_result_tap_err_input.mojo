# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultTapErrInputFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultTapErrInputOther(Movable):
    var code:Int
def main() raises ContextRejectResultTapErrInputFault:
    var calls = 0
    def cb(value: Bool) raises ContextRejectResultTapErrInputFault -> Int:
        raise ContextRejectResultTapErrInputFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultTapErrInputFault]().tap_err(cb).get()
