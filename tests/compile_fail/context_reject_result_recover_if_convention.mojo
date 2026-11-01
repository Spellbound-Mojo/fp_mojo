# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRecoverIfConventionFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRecoverIfConventionOther(Movable):
    var code:Int
def main() raises ContextRejectResultRecoverIfConventionFault:
    var calls = 0
    def cb(mut value: String) raises ContextRejectResultRecoverIfConventionFault -> Bool:
        raise ContextRejectResultRecoverIfConventionFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRecoverIfConventionFault]().recover_if(cb, second).get()
