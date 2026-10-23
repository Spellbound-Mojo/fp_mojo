# error: is not a constructor
from fp.data import Ior, Both
def view(values: List[Int]) -> Span[Int, origin_of(values)]: return Span(values)
def escape(anchor: List[Int]) -> Ior[String, Span[Int, origin_of(anchor)]]:
    var local = List[Int]([1, 2])
    return Ior[String, Span[Int, origin_of(local)]](Both(String("warning"), view(local)))
def main():
    var anchor = List[Int]([3])
    _ = escape(anchor)
