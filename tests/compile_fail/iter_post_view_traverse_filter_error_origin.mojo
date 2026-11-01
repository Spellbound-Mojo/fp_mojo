# error: cannot implicitly convert
# error: origin_of(other)
from fp.functions import kleisli
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily
from fp.callables import OnceUnary
from fp.effects import Reader, run
from fp.data import Result, Err
def wrong(owner: List[Int], other: List[Int]) -> Result[List[Int],Span[Int,origin_of(other)]]:
    var failure = Span(owner)
    comptime Failure = type_of(failure)
    def callback(var value: Int) {failure} -> Result[Optional[Int],Failure]: return Err(failure)
    var chain = kleisli[ResultFamily[Failure]](callback)
    return iterated(range(2)).traverse_filter(chain)
def main():
    _ = wrong([1],[2])
