# error: constraint
from fp.data import ok
from fp.functions import pipeline

def wrong(left: List[Int], right: List[Int]):
    var a = Span(left)
    var b = Span(right)
    comptime A = type_of(a)
    comptime B = type_of(b)
    def success(value: Int) {a} -> A: return a
    def failure(error: Int) {b} -> B: return b
    _ = pipeline(ok[Int](1)).fold(success, failure)
def main(): wrong([1], [2])
