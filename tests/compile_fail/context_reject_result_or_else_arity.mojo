# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultOrElseArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultOrElseArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultOrElseArityFault:
    var calls = 0
    def cb(var value: String, extra: Int) raises ContextRejectResultOrElseArityFault -> Result[Int,String]:
        raise ContextRejectResultOrElseArityFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultOrElseArityFault]().or_else(cb).get()
