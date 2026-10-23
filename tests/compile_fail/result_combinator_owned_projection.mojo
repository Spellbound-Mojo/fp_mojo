# error: no matching method in call to 'flat_tap'
from fp.data import Result, Ok
@fieldwise_init
struct RCRejectedOwner(Movable):
    var value: Int
def project(var value: RCRejectedOwner) -> Result[Int, String]: return Ok(value.value)
def main():
    _ = Result[RCRejectedOwner, String](Ok(RCRejectedOwner(1))).flat_tap(project)
