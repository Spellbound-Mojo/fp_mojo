# error: cannot implicitly convert
# error: origin_of(other)
from fp.functions import pipeline
from fp.data import Result, Err
def wrong(owner: List[Int], other: List[Int]) -> Result[Int, Span[Int, origin_of(other)]]:
    comptime Failure = type_of(Span(owner))
    var failure = Span(owner)
    def reject(var x: Int) {failure} -> Result[Int, Failure]: return Err(failure)
    return pipeline(List[Int]([1])).sum_by_effect(reject).get()
def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner, other)
