# error: invalid call to 'run': lacking evidence to prove correctness
# error: C.First == Self.A
from context_staged_fold_contract_support import OriginStep
from fp.algebra import OptionalFamily
from fp.functions import pipeline

def invalid[a: ImmOrigin, b: ImmOrigin](ref[a] expected: Int, ref[b] other: Int):
    var seed: List[Pointer[Int, b]] = [Pointer(to=other)]
    _ = pipeline(List[Int]([1])).fold_effect[OptionalFamily](seed^).run(OriginStep[a]())

def main():
    var expected = 1
    var other = 2
    invalid(expected, other)
