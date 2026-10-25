# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapBothErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapBothErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapBothErrorFault:
    var calls = 0
    def cb(var value: Int) raises ContextRejectResultMapBothErrorOther -> Int:
        raise ContextRejectResultMapBothErrorOther(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapBothErrorFault]().map_both(cb, second).get()
