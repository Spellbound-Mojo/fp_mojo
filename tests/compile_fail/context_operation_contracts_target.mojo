# error: invalid call to 'forward': violated constraint
from fp.algebra import Applicative, Traversable, ListFamily, ResultFamily
from fp.algebra.contracts import TraverseContract
from fp.callables import Unary
from fp.functions import pipeline
from fp.data import Result, Ok
@fieldwise_init
struct WrongError(Unary):
    comptime Arg = Int
    comptime Out = Result[Int, Int]
    def call(self, var value: Int) -> Self.Out: return Ok(value)
def forward[S: Traversable, G: Applicative, V: Movable & Deinitable, F: Unary](
    var value: V, var function: F
) raises TraverseContract[S, G, V, F].Error -> TraverseContract[S, G, V, F].Out where TraverseContract[S, G, V, F].Compatible:
    return pipeline[S](value^).traverse[G](function^).get()
def main():
    _ = forward[ListFamily, ResultFamily[String]](List[Int]([1]), WrongError())
