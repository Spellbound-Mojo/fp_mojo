# error: invalid call to 'tail_rec_m'
from fp.algebra import IdentityFamily, tail_rec_m
from fp.data import ControlFlow, Break
def main():
    var first = List[Int]([1])
    var second = List[Int]([2])
    def done(var value: Span[Int,origin_of(first)]) -> ControlFlow[Int,Span[Int,origin_of(first)]]:
        return Break(value[0])
    _ = tail_rec_m[IdentityFamily](Span(second), done)
