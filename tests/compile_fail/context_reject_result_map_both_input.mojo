# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapBothInputFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapBothInputOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapBothInputFault:
    var calls = 0
    def cb(var value: Bool) raises ContextRejectResultMapBothInputFault -> Int:
        raise ContextRejectResultMapBothInputFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapBothInputFault]().map_both(cb, second).get()
