# error: cannot implicitly convert
# error: origin_of(other)
from fp.iteration import iterated
def wrong(owner: List[Int], other: List[Int]) -> Optional[List[Span[Int, origin_of(other)]]]:
    comptime View = type_of(Span(owner))
    def keep(var value: View) -> Optional[View]: return Optional(value)
    var pointer: def(var View) thin -> Optional[View] = keep
    return iterated(List[View]([Span(owner)])).traverse(pointer)
def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner, other)
