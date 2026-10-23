# error: no matching method in call to 'flat_tap_err'
from fp.data import Result, Err
@fieldwise_init
struct RSORejectedError(Movable):
    var value: Int
def observe(var error: RSORejectedError) -> Result[Int, RSORejectedError]: return Err(error^)
def main():
    _ = Result[Int, RSORejectedError](Err(RSORejectedError(1))).flat_tap_err(observe)
