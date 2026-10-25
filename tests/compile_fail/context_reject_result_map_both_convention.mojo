# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapBothConventionFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapBothConventionOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapBothConventionFault:
    var calls = 0
    def cb(mut value: Int) raises ContextRejectResultMapBothConventionFault -> Int:
        raise ContextRejectResultMapBothConventionFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapBothConventionFault]().map_both(cb, second).get()
