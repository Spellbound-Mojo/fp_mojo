# error: origin_of(other)
from fp.data import Result, err

def check(owner: List[Int], other: List[Int]):
    var expected = Span(owner)
    var error = Span(other)
    var bad: Result[Int, type_of(expected)] = err[Int](error)
    _ = bad^
def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    check(owner, other)
