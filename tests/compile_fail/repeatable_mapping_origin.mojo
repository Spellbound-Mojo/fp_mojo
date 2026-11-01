# error: cannot implicitly convert
# error: origin_of(local)
from fp.callables import MutableUnary
from fp.iteration import iterated
from std.iter import next
@fieldwise_init
struct View[o: ImmOrigin](MutableUnary):
    comptime Arg = Int
    comptime Out = Span[Int, Self.o]
    var span: Self.Out
    def call_mut(mut self, var value: Int) -> Self.Out: return self.span
def wrong[o: ImmOrigin](ref[o] owner: List[Int]) raises -> Span[Int, o]:
    var local: List[Int] = [1]
    var view = Span(local)
    var pending = iterated(range(1)).map(View[origin_of(local)](view))
    return next(pending)
def main(): pass
