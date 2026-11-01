# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRecoverIfInputFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRecoverIfInputOther(Movable):
    var code:Int
def main() raises ContextRejectResultRecoverIfInputFault:
    var calls = 0
    def cb(value: Bool) raises ContextRejectResultRecoverIfInputFault -> Bool:
        raise ContextRejectResultRecoverIfInputFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRecoverIfInputFault]().recover_if(cb, second).get()
