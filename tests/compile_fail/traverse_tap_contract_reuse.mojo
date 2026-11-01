# error: use of uninitialized value
from algebra_support.tap_contracts import observed, Keep
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.algebra.contracts import TraverseTapContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowOnceCallable, BorrowSignature
def main():
    var source = List[Int]([1,2])
    _ = observed[ListFamily,OptionalFamily](source^,Keep[Int]())
    _ = observed[ListFamily,OptionalFamily](source^,Keep[Int]())
