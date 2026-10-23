# error: invalid call to 'filter': lacking evidence to prove correctness
from fp.functions import piped

def mismatch(left: List[Int], right: List[Int]):
    var views: List[Span[Int, origin_of(left)]] = [Span(left)]
    def select(view: Span[Int, origin_of(right)]) {right} -> Bool:
        return len(view) > 0
    _ = piped(views^).filter(select).get()

def main():
    mismatch([1], [2])
