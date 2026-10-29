# error: use of uninitialized value
from fp.functions import kleisli
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily
from fp.callables import OnceUnary
from fp.effects import Reader, run
from fp.data import Result, Err
def callback(var value: Int) -> Optional[List[Int]]: return None
def main():
    var chain = kleisli[OptionalFamily](callback)
    var source = iterated(range(2))
    _ = source^.flat_traverse(chain)
    _ = source^.flat_traverse(chain)
