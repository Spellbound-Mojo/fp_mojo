# error: constraint
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ListFamily
def mismatch(left: List[Int], right: List[Int]):
    var xs = List[Span[Int, origin_of(left)]]()
    xs.append(Span(left))
    def wrong(value: Span[Int, origin_of(right)]) -> Optional[Bool]: return Optional(True)
    _ = pipeline(xs^).filter_effect[OptionalFamily](wrong)
def main(): mismatch([1], [2])
