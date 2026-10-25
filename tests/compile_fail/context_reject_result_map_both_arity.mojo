# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultMapBothArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultMapBothArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultMapBothArityFault:
    var calls = 0
    def cb(var value: Int, extra: Int) raises ContextRejectResultMapBothArityFault -> Int:
        raise ContextRejectResultMapBothArityFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultMapBothArityFault]().map_both(cb, second).get()
