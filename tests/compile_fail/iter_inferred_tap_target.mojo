# error: constraint
from fp.iteration import iterated
from fp.algebra import ResultFamily
from fp.callables import BorrowSignature
def observe(value: Int) -> Optional[Int]: return Optional(value)
def main():
    _ = iterated(range(2)).traverse_tap[ResultFamily[String]](BorrowSignature[Int,Optional[Int]].capture(observe))
