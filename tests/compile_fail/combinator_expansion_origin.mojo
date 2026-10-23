# error: invalid call to 'pair_with': lacking evidence to prove correctness
from fp.functions import piped
def expansion_mismatch(left: List[Int], right: List[Int]):
    var views: List[Span[Int, origin_of(left)]] = [Span(left)]
    def expansion_project(x: Span[Int, origin_of(right)]) {right} -> Int: return len(x)
    _ = piped(views^).pair_with(expansion_project).get()
def main():
    expansion_mismatch([1], [2])
