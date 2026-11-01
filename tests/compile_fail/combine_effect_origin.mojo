# error: cannot implicitly convert
# error: origin_of(other)
from fp.functions import pipeline
from fp.algebra import ListMonoid
def wrong(owner: List[Int], other: List[Int]) -> Optional[List[Span[Int, origin_of(other)]]]:
    comptime View = type_of(Span(owner))
    var groups = List[Optional[List[View]]]()
    groups.append(Optional(List[View]([Span(owner)])))
    return pipeline(groups^).combine_all_effect[ListMonoid[View]]().get()
def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner, other)
