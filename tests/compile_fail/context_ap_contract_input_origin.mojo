# error: invalid call to 'forward': lacking evidence to prove correctness
# error: constraint declared here needs evidence
from context_ap_contract_support import forward, Plus, Consuming, Missing, KeepMove, MoveState, View
from fp.algebra import OptionalFamily, ListFamily, ResultFamily
from fp.data import Result, Ok

def mismatch[a: ImmOrigin,b: ImmOrigin](ref[a] first: Int,ref[b] second: Int) raises Pointer[Int,a] -> Optional[Pointer[Int,a]]:
    return forward[OptionalFamily](Optional(View[a](False)),Optional(Pointer(to=second)))
def main(): pass
