# error: uninitialized
from fp.functions import kleisli
from fp.algebra import ResultFamily, OptionalFamily, ListFamily
from fp.data import Result, Ok
from fp.callables import MutableUnary, OnceUnary, Unary
from fp.effects import Reader, run
@fieldwise_init
struct Once(OnceUnary):
    comptime Arg = Int
    comptime Out = Optional[Int]
    def call_once(deinit self, var arg: Int) -> Self.Out: return Optional(arg)
def main():
    var chain = kleisli[OptionalFamily](Once())
    _ = chain^.call_once(1)
    _ = chain^.call_once(2)
