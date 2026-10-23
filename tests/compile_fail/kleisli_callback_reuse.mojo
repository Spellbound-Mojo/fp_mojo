# error: uninitialized
from fp.functions import kleisli
from fp.algebra import ResultFamily, OptionalFamily, ListFamily
from fp.data import Result, Ok
from fp.callables import MutableUnary, OnceUnary, Unary
from fp.effects import Reader, run
@fieldwise_init
struct Capture(Movable):
    var text:String
def main():
    var capture=Capture("data")
    def source(x:Int) {var capture^} -> Optional[Int]: return Optional(x+capture.text.byte_length())
    var chain = kleisli[OptionalFamily](source^)
    _ = source(1)
    _ = chain^.call_once(2)
