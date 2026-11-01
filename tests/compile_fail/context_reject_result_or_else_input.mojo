# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultOrElseInputFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultOrElseInputOther(Movable):
    var code:Int
def main() raises ContextRejectResultOrElseInputFault:
    var calls = 0
    def cb(var value: Bool) raises ContextRejectResultOrElseInputFault -> Result[Int,String]:
        raise ContextRejectResultOrElseInputFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultOrElseInputFault]().or_else(cb).get()
