# error: no matching method
# error: constraint
from fp.functions import kleisli, flow
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily
def callback(var value: String) -> Optional[Int]: return None
def main():
    var chain = kleisli[OptionalFamily](callback)
    _ = iterated(range(2)).traverse(chain)
