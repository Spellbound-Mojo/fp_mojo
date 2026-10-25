# The positional binding can also select a native-error overload on Mojo 1.2.
# The companion _named fixture checks the intended family constraint directly.
# error: cannot call function that may raise in a context that cannot raise
from fp.algebra import ValidationFamily, ListMonoid, fail
from fp.functions import piped
from fp.data import Result, Ok
def left(var value: Int) -> Result[Int, List[String]]: return Ok(value)
def right(var error: List[String]) -> Result[Int, List[String]]: return Ok(0)
def main():
    comptime V = ValidationFamily[ListMonoid[String]]
    _ = piped(fail[V, Int](List[String](["bad"]))).redeem_with[V](left, right)
