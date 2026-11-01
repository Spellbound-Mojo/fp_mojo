# error: the callback must be repeatable
from fp.data import Ior, Right
from fp.algebra import IorFamily, StringMonoid
from fp.callables import OnceUnary
@fieldwise_init
struct IOROnce(OnceUnary):
    comptime Arg = Int
    comptime Out = Ior[String, Int]
    def call_once(deinit self, var arg: Int) -> Self.Out: return Right(arg)
def main():
    _ = IorFamily[StringMonoid].collect(IOROnce(), List[Int]([1, 2]))
