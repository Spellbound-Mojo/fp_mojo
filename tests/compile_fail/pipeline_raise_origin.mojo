# error: cannot implicitly convert
# error: origin_of(other)
from fp.data import ok
from fp.functions import pipeline
def wrong(owner: List[Int], other: List[Int]) -> Span[Int, origin_of(other)]:
    return pipeline(ok[Never](Span(owner))).raise_on_err()
def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner, other)
