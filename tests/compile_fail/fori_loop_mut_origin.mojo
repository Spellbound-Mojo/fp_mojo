# error: cannot implicitly convert
# error: origin_of(local)
from fp.control import fori_loop_mut
from fp.callables import MutableBinary
@fieldwise_init
struct Keep[o: ImmOrigin](MutableBinary):
    comptime First = Int
    comptime Second = Span[Int, Self.o]
    comptime Out = Self.Second
    def call_mut(mut self, var index: Int, var view: Self.Second) -> Self.Out: return view

def projected(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    var body = Keep[origin_of(owner)]()
    return fori_loop_mut(0, 3, body, Span(owner))
def wrong[o: ImmOrigin](ref[o] owner: List[Int]) -> Span[Int, o]:
    var local: List[Int] = [1]
    return projected(local)
def main(): pass
