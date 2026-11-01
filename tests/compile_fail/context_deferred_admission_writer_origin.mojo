# error: invalid call to 'writer': lacking evidence to prove correctness
# error: CarrierCompatible
# error: origin_of(left)
# error: origin_of(right)
from fp.effects import WriterT, writer
from fp.algebra import ResultFamily, StringMonoid
from fp.data import Result, Err

def check(left: List[Int], right: List[Int]):
    var expected = Span(left)
    var other = Span(right)
    comptime I = WriterT[ResultFamily[type_of(expected)], StringMonoid]
    _ = writer[I, Int](Result[Tuple[String, Int], type_of(other)](Err(other)))

def main():
    var left = List[Int]([1])
    var right = List[Int]([2])
    check(left, right)
