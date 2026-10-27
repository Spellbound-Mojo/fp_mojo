# error: lacking evidence to prove correctness
from context_state_run_support import Produce, LengthPlus
from fp.effects import State, run
from fp.algebra import map2, pure

def main():
    var first = 1
    var second = 2
    comptime I = State[Int]
    var pending = I.collect(Produce(Pointer(to=first), Pointer(to=second)), List[Int]([1]))
    var combined = map2[I](LengthPlus(), pending^, pure[I](4))
    try:
        _ = run[I](combined^, 8)
    except error:
        pass
