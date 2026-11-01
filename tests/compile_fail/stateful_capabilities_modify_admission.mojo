# error: constraint
from fp.effects import Stateful, State, modify
from fp.callables import UnaryContract, as_unary
def update[C: Stateful, F: UnaryContract & Movable & Deinitable](var f: F) raises C.ModifyError[F] -> C.Modified[F]:
    return modify[C](f^)
def same(var state: Int) -> Int: return state
def main(): _ = update[State[Int]](as_unary(same))
