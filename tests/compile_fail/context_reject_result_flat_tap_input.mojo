# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFlatTapInputFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFlatTapInputOther(Movable):
    var code:Int
def main() raises ContextRejectResultFlatTapInputFault:
    var calls = 0
    def cb(value: Bool) raises ContextRejectResultFlatTapInputFault -> Result[Int,String]:
        raise ContextRejectResultFlatTapInputFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFlatTapInputFault]().flat_tap(cb).get()
