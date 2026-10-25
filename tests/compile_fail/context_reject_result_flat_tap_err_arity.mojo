# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatTapErrArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatTapErrArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatTapErrArityFault:
    var calls = 0
    def cb(value: String, extra: Int) raises ContextRejectResultFlatTapErrArityFault -> Result[Int,String]:
        raise ContextRejectResultFlatTapErrArityFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatTapErrArityFault]().flat_tap_err(cb).get()
