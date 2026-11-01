# error: uninitialized
from fp.functions import kleisli
from fp.algebra import ResultFamily, OptionalFamily, ListFamily
from fp.data import Result, Ok
from fp.callables import MutableUnary, OnceUnary, Unary
from fp.effects import Reader, run
def source(x: Int) -> Reader[Int].Pure[Int]: return Reader[Int].pure(x)
@fieldwise_init
struct Capture(Movable):
    var text:String
def main():
    var capture = Capture("data")
    def next_step(x:Int) {var capture^} -> Reader[Int].Pure[Int]:
        return Reader[Int].pure(x + capture.text.byte_length())
    var chain = kleisli[Reader[Int]](source).then(next_step^)
    var effect = chain.call(1)
    var moved = chain^
    _ = moved^.call_once(2)
    _ = run[Reader[Int]](effect^, 0)
