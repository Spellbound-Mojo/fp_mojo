# The positional binding can also select a native-error overload on Mojo 1.2.
# The companion _named fixture checks the intended family constraint directly.
# error: cannot call function that may raise in a context that cannot raise
from fp.algebra import ValidationFamily, ListMonoid, fail
from fp.functions import piped
def predicate(value: Int) -> Bool: return True
def factory(value: Int) -> List[String]: return ["bad"]
def main():
    comptime V = ValidationFamily[ListMonoid[String]]
    _ = piped(fail[V, Int](List[String](["bad"]))).ensure[V](predicate, factory)
