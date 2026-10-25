# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRecoverIfArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRecoverIfArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultRecoverIfArityFault:
    var calls = 0
    def cb(value: String, extra: Int) raises ContextRejectResultRecoverIfArityFault -> Bool:
        raise ContextRejectResultRecoverIfArityFault(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRecoverIfArityFault]().recover_if(cb, second).get()
