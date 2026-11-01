# error: cannot implicitly convert
# error: origin_of(other)
from algebra_support.filter_effect_contracts import filtered
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.callables import BorrowSignature
def wrong(owner: List[Int], other: List[Int]) -> Optional[List[Span[Int,origin_of(other)]]]:
    comptime View = type_of(Span(owner))
    def inspect(value: View) -> Optional[Bool]: return Optional(len(value) > 0)
    return filtered[ListFamily,OptionalFamily](List[View]([Span(owner)]),BorrowSignature[View,Optional[Bool]].capture(inspect))
def main():
    var owner: List[Int] = [1]
    var other: List[Int] = [2]
    _ = wrong(owner,other)
