"""Generic extensions forward the family's complete bind contract."""
from fp.algebra.protocols import Monad
from fp.algebra import ResultFamily
from fp.callables import OnceUnary
from fp.data import Result, Ok
from fp.functions import pipeline
from std.builtin.rebind import rebind_var
from std.testing import assert_equal

@fieldwise_init
struct ContextBindGenericStep(OnceUnary):
    var increment: Int
    comptime Arg = Int
    comptime Out = Result[Int, String]
    comptime Error = Never
    def call_once(deinit self, var value: Int) -> Self.Out:
        return Ok(value + self.increment)

def forward[U: Movable & Deinitable, F: OnceUnary, T: Movable & Deinitable, E: Movable & Deinitable, I: Monad = ResultFamily[E]](var subject: Result[T, E], var function: F) raises I.BindError[Result[T,E], F] -> I.Bound[Result[T,E], F] where I.Element[Result[T,E]] == F.Arg and F.Out == Result[U,E] and I.BindCompatible[Result[T,E], F]:
    return pipeline[I](subject^).flat_map(function^).get()

def main() raises:
    assert_equal(forward[Int](Result[Int, String](Ok(2)), ContextBindGenericStep(3))._ok().value, 5)
