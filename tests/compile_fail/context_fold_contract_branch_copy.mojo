# error: no matching function in call to 'fold_effect'
from context_fold_contract_support import Once, Owned, SumOwned, owned_items
from fp.algebra import OptionalFamily, ListFamily
from fp.iteration import fold_effect, iterated
from fp.functions import pipeline

def main():
    _ = fold_effect[ListFamily](owned_items(), 0, SumOwned[ListFamily]())
