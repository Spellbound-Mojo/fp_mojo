# error: invalid call to 'forward': violated constraint
# error: constraint declared here evaluated to False
from context_fold_map_contract_support import forward, IncompatibleError, FallibleMonoid
from fp.algebra import OptionalFamily

def main():
    _ = forward[OptionalFamily, FallibleMonoid[False]](IncompatibleError(), List[Int]([1]))
