# error: invalid call
# error: constraint
from algebra_support.post_traversal_contracts import flattened
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.callables import Unary, UnaryContract, OnceUnary, as_unary
from fp.data import Result, Err
from algebra_support.external import PublicMonad
@fieldwise_init
struct Callback(Unary):
    comptime Arg = Int
    comptime Out = Optional[List[Int]]
    comptime Error = String
    def call(self, var value: Self.Arg) raises String -> Self.Out: return None
def main() raises: _ = flattened[ListFamily,PublicMonad[OptionalFamily,1]](List[Int]([1]),Callback())
