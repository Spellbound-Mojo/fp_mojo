# error: invalid call to 'forward': violated constraint
# error: constraint declared here evaluated to False
from context_product_contract_support import forward
from fp.algebra import OptionalFamily, ListFamily, ResultFamily
from fp.data import Result, Ok
from context_branch_admission_support import MoveState

def main(): _ = forward[OptionalFamily](Optional(1),List[Int]([2]))
