# The positional binding can also select a native-error overload on Mojo 1.2.
# The companion _named fixture checks the intended family constraint directly.
# error: cannot call function that may raise in a context that cannot raise
from fp.algebra import ResultFamily
from fp.functions import piped
from fp.data import Result, Ok
def left(var value: Int) -> Result[Int, Int]: return Ok(value)
def right(var error: String) -> Result[Int, Int]: return Ok(0)
def main(): _ = piped(Result[Int, String](Ok(1))).redeem_with[ResultFamily[String]](left, right)
