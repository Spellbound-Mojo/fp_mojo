# error: uninitialized
from fp.functions import kleisli, flow
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily
from fp.effects import Reader, run
def callback(var value: Int) -> Reader[Int].Pure[Int]: return Reader[Int].pure(value)
def main():
    var chain = kleisli[Reader[Int]](callback)
    var pending = iterated(range(2)).traverse(chain)
    var moved = chain^
    _ = moved^.call_once(4)
    _ = run[Reader[Int]](pending^, 0)
