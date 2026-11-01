# error: constraint
from fp.iteration import iterated
from fp.algebra import ResultFamily
from fp.callables import BorrowSignature
def observe(value: Int) -> Optional[Bool]: return Optional(value > 0)
def main():
    _ = iterated(range(2)).filter_effect[ResultFamily[String]](BorrowSignature[Int,Optional[Bool]].capture(observe))
