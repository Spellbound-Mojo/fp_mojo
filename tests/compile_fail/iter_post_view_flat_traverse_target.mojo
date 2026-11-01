# error: no matching method
# error: constraint
from fp.functions import kleisli
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily
from fp.callables import OnceUnary
from fp.effects import Reader, run
from fp.data import Result, Err
def callback(var value: Int) -> Optional[List[Int]]: return None
def main():
    var chain = kleisli[OptionalFamily](callback)
    _ = iterated(range(2)).flat_traverse[ResultFamily[String]](chain)
