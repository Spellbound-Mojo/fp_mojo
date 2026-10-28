# error: aliasing values passed mutably
from fp.callables import MutableBinary
from fp.iteration import iterated
@fieldwise_init
struct Keep[o: Origin](MutableBinary):
    comptime First = Span[Int, Self.o]
    comptime Second = Int
    comptime Out = Span[Int, Self.o]
    var calls: Int
    def call_mut(mut self, var carry: Self.First, var value: Int) -> Self.Out:
        self.calls += 1
        return carry
def main():
    var local: List[Int] = [1]
    var view = Span(local)
    var output = iterated(range(2)).scan_left(Keep[origin_of(local)](0), view).collect_list()
    _ = output^
