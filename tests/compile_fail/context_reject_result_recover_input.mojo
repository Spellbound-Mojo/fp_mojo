# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRecoverInputFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRecoverInputOther(Movable):
    var code:Int
def main() raises ContextRejectResultRecoverInputFault:
    var calls = 0
    def cb(var value: Bool) raises ContextRejectResultRecoverInputFault -> Int:
        raise ContextRejectResultRecoverInputFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRecoverInputFault]().recover(cb).get()
