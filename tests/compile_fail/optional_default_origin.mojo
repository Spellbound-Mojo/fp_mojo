# error: lacking evidence to prove correctness
# error: origin_of(other)
from fp.functions import pipeline

def check(owner: List[Int], other: List[Int]):
    var source = Span(owner)
    var fallback = Span(other)
    comptime Other = type_of(fallback)
    def default() {fallback} -> Other: return fallback
    _ = pipeline(Optional(source)).get_or_else(default)

def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    check(owner, other)
