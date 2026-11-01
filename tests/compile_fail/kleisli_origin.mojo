# error: origin
from fp.functions import kleisli
from fp.algebra import ResultFamily, OptionalFamily, ListFamily
from fp.data import Result, Ok
from fp.callables import MutableUnary, OnceUnary, Unary
from fp.effects import Reader, run
def bad[o:ImmOrigin](ref[o] outer: List[Int]) -> Optional[Span[Int,o]]:
    var local:List[Int] = [1]
    comptime View = Span[Int,origin_of(local)]
    def wrap(var x:View) -> Optional[View]: return Optional(x)
    return kleisli[OptionalFamily](wrap).call_once(Span(local))
def main(): pass
