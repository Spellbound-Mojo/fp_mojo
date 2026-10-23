# error: repeatable
from fp.functions import kleisli
from fp.algebra import ResultFamily, OptionalFamily, ListFamily
from fp.data import Result, Ok
from fp.callables import MutableUnary, OnceUnary, Unary
from fp.effects import Reader, run
@fieldwise_init
struct OnceList(OnceUnary):
    comptime Arg = Int
    comptime Out = List[Int]
    def call_once(deinit self, var arg: Int) -> Self.Out: return [arg]
def source(x:Int) -> List[Int]: return [x,x]
def main():
    _ = kleisli[ListFamily](source).then(OnceList()).call_once(1)
