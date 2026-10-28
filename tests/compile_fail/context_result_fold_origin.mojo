# error: constraint
from fp.data import ok
from fp.functions import pipeline

def wrong(left: List[Int], right: List[Int]):
    var a = Span(left)
    var b = Span(right)
    comptime A = type_of(a)
    comptime B = type_of(b)
    def success(var value: Int) {a} -> A: return a
    def failure(var error: Int) {b} -> B: return b
    _ = pipeline(ok[Int](1)).fold_owned(success, failure)
def main(): wrong([1], [2])
