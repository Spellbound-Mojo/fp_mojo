# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRecoverConventionFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRecoverConventionOther(Movable):
    var code:Int
def main() raises ContextRejectResultRecoverConventionFault:
    var calls = 0
    def cb(mut value: String) raises ContextRejectResultRecoverConventionFault -> Int:
        raise ContextRejectResultRecoverConventionFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRecoverConventionFault]().recover(cb).get()
