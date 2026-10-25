# The positional binding can also select a native-error overload on Mojo 1.2.
# The companion _named fixture checks the intended family constraint directly.
# error: cannot call function that may raise in a context that cannot raise
from fp.algebra import ResultFamily, ListFamily, fail
from fp.functions import piped
from fp.data import Result, Ok, Err
def restore(var error: String) -> Result[Int, Int]: return Err(1)
def main():
    _ = piped(fail[ResultFamily[String], Int](String("bad"))).or_else[ResultFamily[String]](restore).get()
