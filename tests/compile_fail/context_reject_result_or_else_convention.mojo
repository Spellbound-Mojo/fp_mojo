# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultOrElseConventionFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultOrElseConventionOther(Movable):
    var code:Int
def main() raises ContextRejectResultOrElseConventionFault:
    var calls = 0
    def cb(mut value: String) raises ContextRejectResultOrElseConventionFault -> Result[Int,String]:
        raise ContextRejectResultOrElseConventionFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultOrElseConventionFault]().or_else(cb).get()
