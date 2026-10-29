# error: cannot implicitly convert
# error: origin_of(other)
from fp.iteration import iterated
def wrong(owner: List[Int], other: List[Int]) -> Optional[List[Span[Int, origin_of(other)]]]:
    comptime View = type_of(Span(owner))
    return iterated(List[Optional[View]]([Optional(Span(owner))])).sequence()
def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner,other)
