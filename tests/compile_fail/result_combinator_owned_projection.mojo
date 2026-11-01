# Mojo 1.2: bind C before checking the invalid native signature.
# Removing this hint reproduces a compiler crash; see native-boundaries.md.
# error: value passed to 'C' cannot be converted
# error: no matching method in call to 'flat_tap'
from fp.data import Result, Ok
@fieldwise_init
struct RCRejectedOwner(Movable):
    var value: Int
def project(var value: RCRejectedOwner) -> Result[Int, String]: return Ok(value.value)
def main():
    _ = Result[RCRejectedOwner, String](Ok(RCRejectedOwner(1))).flat_tap[C=type_of(project)](project)
