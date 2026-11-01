# error: origin_of(local)
from fp.iteration import iterated
from fp.callables import Binary
from std.iter import next

@fieldwise_init
struct I12View[o: ImmOrigin](Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Span[Int, Self.o]
    var view: Self.Out
    def call(self,var index: Int,var value: Int) -> Self.Out:
        return self.view

def check(anchor: List[Int]) raises:
    var local: List[Int] = [1,2]
    var mapped = iterated(range(2)).map_with_index(I12View(Span(local)))
    var result: Span[Int,origin_of(anchor)] = next(mapped)
    print(result[0])

def main() raises:
    var anchor: List[Int] = [1,2]
    check(anchor)
