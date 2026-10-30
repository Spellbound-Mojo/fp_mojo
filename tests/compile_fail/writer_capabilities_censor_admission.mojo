# error: constraint
from fp.effects import Censor, Writer, tell, censor
from fp.callables import UnaryContract, as_unary
from fp.algebra import StringMonoid
def scope[C: Censor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises C.CensorError[V, F] -> C.Censored[V, F]:
    return censor[C](value^, f^)
def same(var log: String) -> String: return log^
def main():
    comptime W = Writer[StringMonoid]
    _ = scope[W](as_unary(same), tell[W](String("a")))
