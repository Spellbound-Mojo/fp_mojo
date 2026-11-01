# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultEnsureErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultEnsureErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultEnsureErrorFault:
    var calls = 0
    def cb(value: Int) raises ContextRejectResultEnsureErrorOther -> Bool:
        raise ContextRejectResultEnsureErrorOther(1)
    def second(value: Int) -> String: return String("err")
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultEnsureErrorFault]().ensure(cb, second).get()
