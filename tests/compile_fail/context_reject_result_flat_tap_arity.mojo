# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatTapArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatTapArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatTapArityFault:
    var calls = 0
    def cb(value: Int, extra: Int) raises ContextRejectResultFlatTapArityFault -> Result[Int,String]:
        raise ContextRejectResultFlatTapArityFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatTapArityFault]().flat_tap(cb).get()
