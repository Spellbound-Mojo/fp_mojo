# error: constraint
from fp.functions import pipeline
def bad(left: List[Int], right: List[Int]):
    comptime R = Span[Int,origin_of(right)]
    def check(value: R) -> Optional[Int]: return Optional(1)
    _ = pipeline(Optional(Span(left))).flat_tap(check).get()
def main(): bad([1],[2])
