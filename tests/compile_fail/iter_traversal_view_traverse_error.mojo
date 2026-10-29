# error: cannot call function that may raise
from fp.functions import kleisli, flow
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily
def callback(var value: Int) raises Int -> Optional[Int]: raise value
def main() raises:
    var chain = kleisli[OptionalFamily](callback)
    _ = iterated(range(2)).traverse(chain)
