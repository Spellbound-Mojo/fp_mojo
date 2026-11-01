# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok, Err
@fieldwise_init
struct ContextRejectResultFollowedByArityFault(Movable):
    var code: Int
@fieldwise_init
struct ContextRejectResultFollowedByArityOther(Movable):
    var code:Int
def main() raises ContextRejectResultFollowedByArityFault:
    var calls = 0
    def cb(extra: Int) raises ContextRejectResultFollowedByArityFault -> Result[Int,String]:
        raise ContextRejectResultFollowedByArityFault(1)
    _ = pipeline(Result[Int,String](Ok(1))).raising[ContextRejectResultFollowedByArityFault]().followed_by(cb).get()
