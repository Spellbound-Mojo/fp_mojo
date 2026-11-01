# error: use of uninitialized value
from algebra_support.post_traversal_contracts import selected
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.callables import Unary, UnaryContract, OnceUnary, as_unary
from fp.data import Result, Err
@fieldwise_init
struct Callback(Unary):
    comptime Arg = Int
    comptime Out = Optional[Optional[Int]]
    def call(self, var value: Self.Arg) -> Self.Out: return None
def main():
    var source = List[Int]([1])
    _ = selected[ListFamily,OptionalFamily](source^,Callback())
    _ = selected[ListFamily,OptionalFamily](source^,Callback())
