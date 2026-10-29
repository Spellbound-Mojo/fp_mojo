# error: cannot implicitly convert
# error: origin_of(other)
from fp.iteration import iterated
from fp.data import Result, Err
def wrong(owner: List[Int], other: List[Int]) -> Result[List[Int], Span[Int, origin_of(other)]]:
    comptime Failure = type_of(Span(owner))
    def fail(var error: Failure) -> Result[Int, Failure]: return Err(error)
    var pointer: def(var Failure) thin -> Result[Int, Failure] = fail
    return iterated(List[Failure]([Span(owner)])).traverse(pointer)
def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner, other)
