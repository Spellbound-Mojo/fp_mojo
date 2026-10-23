# error: constraint
from fp.data import Result, Ok
def mismatch(left: List[Int], right: List[Int]):
    var value = Result[Span[Int, origin_of(left)], String](Ok(Span(left)))
    def project(view: Span[Int, origin_of(right)]) -> Result[Int, String]: return Ok(len(view))
    _ = value^.flat_tap(project)
def main(): mismatch([1], [2])
