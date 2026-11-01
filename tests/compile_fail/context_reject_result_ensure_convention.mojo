# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultEnsureConventionFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultEnsureConventionOther(Movable):
    var code:Int
def main() raises ContextRejectResultEnsureConventionFault:
    var calls = 0
    def cb(mut value: Int) raises ContextRejectResultEnsureConventionFault -> Bool:
        raise ContextRejectResultEnsureConventionFault(1)
    def second(value: Int) -> String: return String("err")
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultEnsureConventionFault]().ensure(cb, second).get()
