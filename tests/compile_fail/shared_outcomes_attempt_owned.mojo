# Mojo 1.2: bind C before checking the invalid native signature.
# Removing this hint reproduces a compiler crash; see native-boundaries.md.
# error: value passed to 'C' cannot be converted
# error: no matching method
from fp.algebra import ResultFamily
from fp.functions import piped
from fp.data import Result, Ok
def inspect(var value: Result[Int, String]) -> Result[Int, String]: return value^
def main(): _ = piped(Result[Int, String](Ok(1))).attempt_tap[ResultFamily[String], C=type_of(inspect)](inspect)
