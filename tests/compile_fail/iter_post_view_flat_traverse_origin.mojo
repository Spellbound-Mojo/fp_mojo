# error: cannot implicitly convert
# error: origin_of(other)
from fp.functions import kleisli
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily
from fp.callables import OnceUnary
from fp.effects import Reader, run
from fp.data import Result, Err
def wrong(owner: List[Int], other: List[Int]) -> Optional[List[Span[Int,origin_of(other)]]]:
    comptime View = Span[Int,origin_of(owner)]
    def callback(var value: Int) {owner} -> Optional[List[View]]: return Optional(List[View]([Span(owner)]))
    var chain = kleisli[OptionalFamily](callback)
    return iterated(range(2)).flat_traverse(chain)
def main():
    _ = wrong([1],[2])
