# error: no matching method in call to 'filter'
from fp.functions import pipeline

def mismatch(left: List[Int], right: List[Int]):
    var views: List[Span[Int, origin_of(left)]] = [Span(left)]
    def select(view: Span[Int, origin_of(right)]) {right} -> Bool:
        return len(view) > 0
    _ = pipeline(views^).filter(select).get()

def main():
    mismatch([1], [2])
