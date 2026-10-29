# error: cannot implicitly convert
# error: origin_of(other)
from fp.functions import kleisli, flow
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Err
def wrong(owner: List[Int], other: List[Int]) -> Result[List[Int], Span[Int, origin_of(other)]]:
    var failure = Span(owner)
    comptime Failure = type_of(failure)
    def callback(var value: Int) {failure} -> Result[Int, Failure]: return Err(failure)
    var chain = kleisli[ResultFamily[Failure]](callback)
    return iterated(range(2)).traverse(chain)
def main(): _ = wrong([1], [2])
