# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatTapErrInputFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatTapErrInputOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatTapErrInputFault:
    var calls = 0
    def cb(value: Bool) raises ContextRejectResultFlatTapErrInputFault -> Result[Int,String]:
        raise ContextRejectResultFlatTapErrInputFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatTapErrInputFault]().flat_tap_err(cb).get()
