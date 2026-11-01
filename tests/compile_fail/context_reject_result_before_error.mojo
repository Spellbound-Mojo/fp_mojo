# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultBeforeErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultBeforeErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultBeforeErrorFault:
    var calls = 0
    def cb() raises ContextRejectResultBeforeErrorOther -> Result[Int,String]:
        raise ContextRejectResultBeforeErrorOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultBeforeErrorFault]().before(cb).get()
