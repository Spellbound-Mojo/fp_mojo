# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultBeforeArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultBeforeArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultBeforeArityFault:
    var calls = 0
    def cb(extra: Int) raises ContextRejectResultBeforeArityFault -> Result[Int,String]:
        raise ContextRejectResultBeforeArityFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultBeforeArityFault]().before(cb).get()
