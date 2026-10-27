# error: invalid call to 'forward': violated constraint
# error: constraint declared here evaluated to False
from context_fold_map_contract_support import forward, Text, OnceText, Owned, OwnedSum, ProduceOwned, ProduceSource
from fp.algebra import OptionalFamily, ListFamily, StringMonoid, ListMonoid

def main():
    _ = forward[OptionalFamily, StringMonoid](Text[OptionalFamily](), List[String](["a"]))
