# error: no matching method in call to 'fold_effect'
from context_fold_contract_support import Once, Owned, SumOwned
from fp.algebra import OptionalFamily, ListFamily
from fp.iteration import fold_effect, iterated
from fp.functions import pipeline

def main():
    _ = pipeline(List[Int]([1, 2])).fold_effect[OptionalFamily](Once[OptionalFamily](), 0)
