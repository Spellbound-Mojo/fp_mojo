# error: alias
from fp.functions import kleisli
from fp.algebra import ResultFamily, OptionalFamily, ListFamily
from fp.data import Result, Ok
from fp.callables import MutableUnary, OnceUnary, Unary
from fp.effects import Reader, run
def source(x: Int) -> Reader[Int].Pure[Int]: return Reader[Int].pure(x)
def main():
    var chain = kleisli[Reader[Int]](source).then(source)
    var first = chain.call_mut(1)
    var second = chain.call(2)
    _ = (first^, second^)
