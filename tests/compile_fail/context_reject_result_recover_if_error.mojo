# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultRecoverIfErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultRecoverIfErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultRecoverIfErrorFault:
    var calls = 0
    def cb(value: String) raises ContextRejectResultRecoverIfErrorOther -> Bool:
        raise ContextRejectResultRecoverIfErrorOther(1)
    def second(var value: String) -> Int: return 1
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultRecoverIfErrorFault]().recover_if(cb, second).get()
