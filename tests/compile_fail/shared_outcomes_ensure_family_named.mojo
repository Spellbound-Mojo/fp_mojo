# error: no matching method
from fp.algebra import ValidationFamily, ListMonoid, fail
from fp.functions import pipeline
def predicate(value: Int) -> Bool: return True
def factory(value: Int) -> List[String]: return ["bad"]
def main():
    comptime V = ValidationFamily[ListMonoid[String]]
    _ = pipeline(fail[V, Int](List[String](["bad"]))).ensure[I=V](predicate, factory)
