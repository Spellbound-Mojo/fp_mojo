# error: invalid call to 'checked': violated constraint
# error: constraint declared here evaluated to False
from context_staged_fold_contract_support import checked, MissingFoldReceiver
from algebra_support.box import BoxMonad
from context_fold_contract_support import Once

def main():
    _ = checked[BoxMonad](Once[BoxMonad](), 0, List[Int]([1]))
