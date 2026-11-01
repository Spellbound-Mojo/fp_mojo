# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultEnsureInputFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultEnsureInputOther(Movable):
    var code:Int
def main() raises ContextRejectResultEnsureInputFault:
    var calls = 0
    def cb(value: Bool) raises ContextRejectResultEnsureInputFault -> Bool:
        raise ContextRejectResultEnsureInputFault(1)
    def second(value: Int) -> String: return String("err")
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultEnsureInputFault]().ensure(cb, second).get()
