# error: cannot be converted
# error: origin_of(other)
from fp.data import ok
from fp.functions import pipeline

def check(owner: List[Int], other: List[Int]):
    var source = Span(owner)
    var fallback = Span(other)
    _ = pipeline(Optional(source)).get_or(fallback)

def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    check(owner, other)
