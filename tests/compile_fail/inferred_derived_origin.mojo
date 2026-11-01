# error: cannot implicitly convert
# error: origin_of(other)
from fp.functions import pipeline
def wrong(owner: List[Int], other: List[Int]) -> Optional[List[Span[Int, origin_of(other)]]]:
    comptime View = type_of(Span(owner))
    var effects = List[Optional[Optional[View]]]([Optional(Optional(Span(owner)))])
    return pipeline(effects^).sequence_filter().get()
def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner, other)
