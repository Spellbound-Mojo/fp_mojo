# error: cannot implicitly convert
# error: origin_of(local)
from fp.control import while_loop
from fp.callables import MutableUnary, BorrowSignature
@fieldwise_init
struct Keep[o: ImmOrigin](MutableUnary):
    comptime Arg = Span[Int, Self.o]
    comptime Out = Self.Arg
    def call_mut(mut self, var view: Self.Arg) -> Self.Out: return view

def projected(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    comptime View = Span[Int, origin_of(owner)]
    def more(value: View) -> Bool: return False
    var body = Keep[origin_of(owner)]()
    return while_loop(BorrowSignature[View, Bool].capture(more), body^, View(owner))
def wrong[o: ImmOrigin](ref[o] owner: List[Int]) -> Span[Int, o]:
    var local: List[Int] = [1]
    return projected(local)
def main(): pass
