# error: uninitialized
from fp.functions import kleisli
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily
from fp.callables import OnceUnary
from fp.effects import Reader, run
from fp.data import Result, Err
def callback(var value: Int) -> Reader[Int].Pure[Optional[Int]]: return Reader[Int].pure(Optional(value))
def main():
    var chain = kleisli[Reader[Int]](callback)
    var pending = iterated(range(2)).traverse_filter(chain)
    var moved = chain^
    _ = moved^.call_once(4)
    _ = run[Reader[Int]](pending^,0)
