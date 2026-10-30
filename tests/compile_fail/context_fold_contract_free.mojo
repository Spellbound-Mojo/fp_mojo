# error: no matching function in call to 'fold_effect'
from context_fold_contract_support import Once, Owned, SumOwned
from fp.algebra import OptionalFamily, ListFamily
from fp.iteration import fold_effect, iterated
from fp.functions import piped

def main():
    _ = fold_effect[OptionalFamily](List[Int]([1, 2]), 0, Once[OptionalFamily]())
