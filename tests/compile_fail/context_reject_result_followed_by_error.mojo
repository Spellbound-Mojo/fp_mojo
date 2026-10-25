# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFollowedByErrorFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFollowedByErrorOther(Movable):
    var code:Int
def main() raises ContextRejectResultFollowedByErrorFault:
    var calls = 0
    def cb() raises ContextRejectResultFollowedByErrorOther -> Result[Int,String]:
        raise ContextRejectResultFollowedByErrorOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFollowedByErrorFault]().followed_by(cb).get()
