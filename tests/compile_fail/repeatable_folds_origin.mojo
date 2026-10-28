# error: cannot implicitly convert
# error: origin_of(local)
from fp.callables import MutableBinary
from fp.iteration import iterated
@fieldwise_init
struct Keep[o: ImmOrigin](MutableBinary):
    comptime First = Span[Int, Self.o]
    comptime Second = Int
    comptime Out = Span[Int, Self.o]
    var calls: Int
    def call_mut(mut self, var carry: Self.First, var value: Int) -> Self.Out:
        self.calls += 1
        return carry
def scanned(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    var view = Span(owner)
    return iterated(range(2)).fold_left(Keep[origin_of(owner)](0), view)
def wrong[o: ImmOrigin](ref[o] owner: List[Int]) -> Span[Int, o]:
    var local: List[Int] = [1]
    return scanned(local)
def main(): pass
