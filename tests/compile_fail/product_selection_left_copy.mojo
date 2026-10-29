# error: invalid call to 'product_r': violated constraint
from fp.functions import pipeline
from context_branch_admission_support import MoveState
def main(): _ = pipeline(List[MoveState]()).product_r(List[Int]([2]))
