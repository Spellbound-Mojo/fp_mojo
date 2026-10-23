# error: constraint
from fp.functions import piped
from fp.algebra import OptionalFamily
def mismatch(left: List[Int], right: List[Int]):
    var values = List[Span[Int, origin_of(left)]]()
    values.append(Span(left))
    def project(view: Span[Int, origin_of(right)]) -> Optional[Int]: return Optional(len(view))
    _ = piped(values^).traverse_tap[OptionalFamily](project)
def main(): mismatch([1], [2])
