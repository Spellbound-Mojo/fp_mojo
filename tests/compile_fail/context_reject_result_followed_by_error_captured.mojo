# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFollowedByErrorCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFollowedByErrorCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFollowedByErrorCapturedFault:
    var calls = 0
    def cb() raises ContextRejectResultFollowedByErrorCapturedOther {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFollowedByErrorCapturedOther(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFollowedByErrorCapturedFault]().followed_by(cb).get()
