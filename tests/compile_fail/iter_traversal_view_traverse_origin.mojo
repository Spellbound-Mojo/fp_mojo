# error: cannot implicitly convert
# error: origin_of(other)
from fp.functions import kleisli
from fp.iteration import iterated
from fp.algebra import OptionalFamily
def wrong(owner: List[Int], other: List[Int]) -> Optional[List[Span[Int, origin_of(other)]]]:
    comptime View = type_of(Span(owner))
    def callback(var value: View) -> Optional[View]: return Optional(value)
    var chain = kleisli[OptionalFamily](callback)
    return iterated(List[View]([Span(owner)])).traverse(chain)
def main(): _ = wrong([1], [2])
