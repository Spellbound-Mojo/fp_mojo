from fp.algebra import ApContract, Applicative, OptionalFamily, ap
from fp.callables import OnceUnary
from std.testing import assert_equal

@fieldwise_init
struct Add(OnceUnary):
    var amount: Int
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var value: Int) -> Int:
        return value + self.amount

def apply[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable](
    var callbacks: V, var values: W
) raises ApContract[I, V, W].Error -> ApContract[I, V, W].Out where ApContract[I, V, W].Compatible:
    return ap[I](callbacks^, values^)

def main() raises:
    var result = apply[OptionalFamily](Optional(Add(3)), Optional(4))
    assert_equal(result.value(), 7)
    print("applied:", result.value())
