# error: no matching method
# error: constraint
from fp.functions import kleisli, flow
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily
from fp.callables import OnceUnary
@fieldwise_init
struct Callback(OnceUnary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    def call_once(deinit self, var value: Int) -> Self.Out: return Optional(value)
def main():
    var chain = kleisli[OptionalFamily](Callback())
    _ = iterated(range(2)).traverse_void(chain^)
