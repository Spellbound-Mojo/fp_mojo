# error: no matching method in call to 'ensure'
from fp.algebra import ValidationFamily, ListMonoid, fail
from fp.functions import pipeline
def predicate(value: Int) -> Bool: return True
def factory(value: Int) -> List[String]: return ["bad"]
def main():
    comptime V = ValidationFamily[ListMonoid[String]]
    _ = pipeline[V](fail[V, Int](List[String](["bad"]))).ensure(predicate, factory)
