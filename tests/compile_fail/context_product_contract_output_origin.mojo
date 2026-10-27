# error: cannot implicitly convert
from context_product_contract_support import forward
from fp.algebra import OptionalFamily, ListFamily, ResultFamily
from fp.data import Result, Ok
from context_branch_admission_support import MoveState

def mismatch[a: ImmOrigin,b: ImmOrigin](ref[a] first: Int,ref[b] second: Int) -> Optional[Tuple[Pointer[Int,a],Pointer[Int,a]]]:
    return forward[OptionalFamily](Optional(Pointer(to=first)),Optional(Pointer(to=second)))
def main(): pass
