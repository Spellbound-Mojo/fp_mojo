# error: constraint
from algebra_support.tap_contracts import observed, Keep
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.algebra.contracts import TraverseTapContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowOnceCallable, BorrowSignature
def main(): _ = observed[ListFamily,OptionalFamily](List[Int]([1,2]),Keep[String]())
