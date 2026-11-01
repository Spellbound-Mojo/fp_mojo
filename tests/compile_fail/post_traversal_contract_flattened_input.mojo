# error: invalid call
# error: constraint
from algebra_support.post_traversal_contracts import flattened
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.callables import Unary, UnaryContract, OnceUnary, as_unary
from fp.data import Result, Err
@fieldwise_init
struct Callback(Unary):
    comptime Arg = String
    comptime Out = Optional[List[Int]]
    def call(self, var value: Self.Arg) -> Self.Out: return None
def main(): _ = flattened[ListFamily,OptionalFamily](List[Int]([1]),Callback())
