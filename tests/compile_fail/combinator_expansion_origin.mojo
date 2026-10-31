# error: no matching method in call to 'pair_with'
# error: cannot be converted from 'def(x: Span[Int, origin_of(right)]) -> Int'
from fp.functions import pipeline
def expansion_mismatch(left: List[Int], right: List[Int]):
    var views: List[Span[Int, origin_of(left)]] = [Span(left)]
    def expansion_project(x: Span[Int, origin_of(right)]) {right} -> Int: return len(x)
    _ = pipeline(views^).pair_with(expansion_project).get()
def main():
    expansion_mismatch([1], [2])
