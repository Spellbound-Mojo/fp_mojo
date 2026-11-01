# error: use of uninitialized value
from algebra_support.filter_effect_contracts import filtered, Even, FailingCompaction
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.algebra.contracts import FilterEffectContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowOnceCallable, BorrowSignature
def main():
    var source = List[Int]([1,2])
    _ = filtered[ListFamily,OptionalFamily](source^,Even())
    _ = filtered[ListFamily,OptionalFamily](source^,Even())
