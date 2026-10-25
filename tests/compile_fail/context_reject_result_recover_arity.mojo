# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRecoverArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRecoverArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultRecoverArityFault:
    var calls = 0
    def cb(var value: String, extra: Int) raises ContextRejectResultRecoverArityFault -> Int:
        raise ContextRejectResultRecoverArityFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRecoverArityFault]().recover(cb).get()
