# error: cannot implicitly convert
# error: origin_of(other)
from fp.iteration import iterated
from fp.callables import BorrowSignature
def wrong(owner: List[Int], other: List[Int]) -> Optional[List[Span[Int,origin_of(other)]]]:
    comptime View = type_of(Span(owner))
    def inspect(value: View) -> Optional[Bool]: return Optional(len(value) > 0)
    return iterated(List[View]([Span(owner)])).filter_effect(BorrowSignature[View,Optional[Bool]].capture(inspect))
def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner,other)
