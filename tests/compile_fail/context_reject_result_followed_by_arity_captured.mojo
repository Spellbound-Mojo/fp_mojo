# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFollowedByArityCapturedFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFollowedByArityCapturedOther(Movable):
    var code:Int
def main() raises ContextRejectResultFollowedByArityCapturedFault:
    var calls = 0
    def cb(extra: Int) raises ContextRejectResultFollowedByArityCapturedFault {mut calls} -> Result[Int,String]:
        calls += 1
        raise ContextRejectResultFollowedByArityCapturedFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFollowedByArityCapturedFault]().followed_by(cb).get()
