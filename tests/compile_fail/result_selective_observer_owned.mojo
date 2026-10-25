# Mojo 1.2: bind C before checking the invalid native signature.
# Removing this hint reproduces a compiler crash; see native-boundaries.md.
# error: value passed to 'C' cannot be converted
# error: no matching method in call to 'flat_tap_err'
from fp.data import Result, Err
@fieldwise_init
struct RSORejectedError(Movable):
    var value: Int
def observe(var error: RSORejectedError) -> Result[Int, RSORejectedError]: return Err(error^)
def main():
    _ = Result[Int, RSORejectedError](Err(RSORejectedError(1))).flat_tap_err[C=type_of(observe)](observe)
