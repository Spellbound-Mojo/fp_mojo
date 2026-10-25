# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapErrConventionFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapErrConventionOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapErrConventionFault:
    var calls = 0
    def cb(mut value: String) raises ContextRejectResultMapErrConventionFault -> Int:
        raise ContextRejectResultMapErrConventionFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapErrConventionFault]().map_err(cb).get()
