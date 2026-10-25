# error: no matching method
from fp.algebra import ValidationFamily, ListMonoid, fail
from fp.functions import piped
def predicate(value: Int) -> Bool: return True
def factory(value: Int) -> List[String]: return ["bad"]
def main():
    comptime V = ValidationFamily[ListMonoid[String]]
    _ = piped(fail[V, Int](List[String](["bad"]))).ensure[I=V](predicate, factory)
