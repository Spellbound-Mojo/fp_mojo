# error: no matching method
# error: constraint
from fp.functions import kleisli
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily
from fp.callables import OnceUnary
from fp.effects import Reader, run
from fp.data import Result, Err
@fieldwise_init
struct Callback(OnceUnary):
    comptime Arg = Int
    comptime Out = Optional[List[Int]]
    def call_once(deinit self, var value: Int) -> Self.Out: return None
def main():
    var chain = kleisli[OptionalFamily](Callback())
    _ = iterated(range(2)).flat_traverse(chain^)
