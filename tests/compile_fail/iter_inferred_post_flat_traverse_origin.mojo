# error: cannot implicitly convert
# error: origin_of(other)
from fp.iteration import iterated
from fp.callables import Unary, OnceUnary, as_unary
from fp.algebra import OptionalFamily, ResultFamily
def wrong(owner: List[Int], other: List[Int]) -> Optional[List[Span[Int,origin_of(other)]]]:
    comptime View = type_of(Span(owner))
    def keep(var value: View) -> Optional[List[View]]: return Optional(List[View]([value]))
    return iterated(List[View]([Span(owner)])).flat_traverse(as_unary(keep))
def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner,other)
