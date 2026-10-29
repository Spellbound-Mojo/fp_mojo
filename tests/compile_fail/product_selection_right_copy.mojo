# error: invalid call to 'product_l': violated constraint
from fp.algebra import product_l, ListFamily
from context_branch_admission_support import MoveState
def main(): _ = product_l[ListFamily](List[Int]([2]),List[MoveState]())
