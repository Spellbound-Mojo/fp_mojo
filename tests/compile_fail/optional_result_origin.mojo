# error: origin_of(other)
from fp.functions import pipeline
from fp.data import Result

def check(owner: List[Int], other: List[Int]):
    var expected = Span(owner)
    var error = Span(other)
    comptime E = type_of(error)
    def factory() {error} -> E: return error
    var bad: Result[Int, type_of(expected)] = pipeline(Optional[Int]()).to_result(factory).get()
    _ = bad^

def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    check(owner, other)
