# error: no matching method in call to 'attempt_tap'
from fp.data import Result, Ok
@fieldwise_init
struct RORejectedOwner(Movable):
    var value: Int
def inspect(var value: Result[RORejectedOwner, String]) -> Result[Int, String]: return Ok(0)
def main(): _ = Result[RORejectedOwner, String](Ok(RORejectedOwner(1))).attempt_tap(inspect)
