# error: lacking evidence
from fp.functions import pipeline
def check(left:List[Int],right:List[Int]):
    comptime L=type_of(Span(left))
    comptime R=type_of(Span(right))
    def bad(var value:L) -> Optional[L]: return Optional(value)
    _ = pipeline(List[R]([Span(right)])).find_map(bad).get()
def main(): check(List[Int]([1]),List[Int]([2]))
