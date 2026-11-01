# error: invalid call to 'forward': lacking evidence to prove correctness
from context_map2_contract_support import forward, Keep, Add, OnceAdd, MoveLeft, MoveRight, MoveState
from fp.algebra import OptionalFamily, ListFamily, ResultFamily
from fp.data import Result, Ok

def mismatch[a: ImmOrigin,b: ImmOrigin](ref[b] value: Int):
    _ = forward[OptionalFamily](Keep[a](),Optional(Pointer(to=value)),Optional(2))
def main(): pass
