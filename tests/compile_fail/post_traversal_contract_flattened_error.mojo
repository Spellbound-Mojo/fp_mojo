# error: cannot call function that may raise
from algebra_support.post_traversal_contracts import flattened
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.callables import Unary, UnaryContract, OnceUnary, as_unary
from fp.data import Result, Err
@fieldwise_init
struct Callback(Unary):
    comptime Arg = Int
    comptime Out = Optional[List[Int]]
    comptime Error = Int
    def call(self, var value: Self.Arg) raises Int -> Self.Out: return None
def main(): _ = flattened[ListFamily,OptionalFamily](List[Int]([1]),Callback())
