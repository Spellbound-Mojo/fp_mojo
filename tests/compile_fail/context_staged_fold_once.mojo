# error: invalid call to 'forward': violated constraint
# error: constraint declared here evaluated to False
from context_staged_fold_contract_support import forward
from context_fold_contract_support import Add, Once, SumOwned, owned_items
from fp.algebra import OptionalFamily, ListFamily
from fp.functions import pipeline

def main():
    _ = forward[OptionalFamily](Once[OptionalFamily](), 0, List[Int]([1]))
