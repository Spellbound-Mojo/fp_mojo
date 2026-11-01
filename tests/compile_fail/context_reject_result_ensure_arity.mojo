# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultEnsureArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultEnsureArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultEnsureArityFault:
    var calls = 0
    def cb(value: Int, extra: Int) raises ContextRejectResultEnsureArityFault -> Bool:
        raise ContextRejectResultEnsureArityFault(1)
    def second(value: Int) -> String: return String("err")
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultEnsureArityFault]().ensure(cb, second).get()
