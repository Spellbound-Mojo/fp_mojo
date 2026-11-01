# error: lacking evidence to prove correctness
# error: origin_of(local)
# error: origin_of(anchor)
from fp.functions import pipeline
from fp.data import Result, Err

def check(anchor: List[Int], local: List[Int]):
    var actual = Span(local)
    var expected = Span(anchor)
    comptime Local = type_of(actual)
    comptime Expected = type_of(expected)
    def callback(var value: Int) {expected} -> Result[Int, Expected]:
        return Err(expected)
    # Returning a different error origin must be rejected before evaluation.
    _ = pipeline(Result[Int, Local](Err(actual))).flat_map(callback).get()
def main():
    var anchor: List[Int] = [1]
    var local: List[Int] = [2]
    check(anchor, local)
