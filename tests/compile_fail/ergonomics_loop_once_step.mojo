# error: no matching
from fp.algebra import IdentityFamily, tail_rec_m
from fp.data import ControlFlow, Break
from fp.callables import OnceUnary
@fieldwise_init
struct OnlyOnce(OnceUnary):
    comptime Arg = Int
    comptime Out = ControlFlow[Int,Int]
    def call_once(deinit self, var a: Int) -> Self.Out: return Break(a)
def main(): _ = tail_rec_m[IdentityFamily](1, OnlyOnce())
