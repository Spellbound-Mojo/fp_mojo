# Mojo 1.2: bind G before checking the invalid native signature.
# Removing this hint reproduces a compiler crash; see native-boundaries.md.
# error: value passed to 'G' cannot be converted
# error: no matching method
from fp.algebra import ResultFamily
from fp.functions import piped
from fp.data import Result, Ok
def predicate(value: Int) -> Bool: return False
def factory(var value: Int) -> String: return "bad"
def main(): _ = piped(Result[Int, String](Ok(1))).ensure[ResultFamily[String], G=type_of(factory)](predicate, factory)
