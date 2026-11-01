# error: use of uninitialized value
from fp.functions import kleisli, flow
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily
def callback(var value: Int) -> Optional[Int]: return None
def main():
    var chain = kleisli[OptionalFamily](callback)
    var source = iterated(range(2))
    _ = source^.traverse(chain)
    _ = source^.traverse(chain)
