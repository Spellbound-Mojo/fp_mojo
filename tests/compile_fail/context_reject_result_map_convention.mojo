# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapConventionFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapConventionOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapConventionFault:
    var calls = 0
    def cb(mut value: Int) raises ContextRejectResultMapConventionFault -> Int:
        raise ContextRejectResultMapConventionFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapConventionFault]().map(cb).get()
