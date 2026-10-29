# error: cannot implicitly convert
# error: origin_of(other)
from fp.iteration import iterated
from fp.data import Result, Err
def wrong(owner: List[Int], other: List[Int]) -> Result[NoneType, Span[Int, origin_of(other)]]:
    comptime Failure = type_of(Span(owner))
    def fail(var value: Int) {owner} -> Result[Int, Failure]: return Err(Span(owner))
    return iterated(range(2)).traverse_void(fail)
def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner, other)
