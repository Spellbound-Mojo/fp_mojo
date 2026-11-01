# error: lacking evidence to prove correctness
from context_state_run_support import Produce
from fp.effects import State, run

def main():
    var first = 1
    var second = 2
    comptime I = State[Int]
    var pending = I.collect(Produce(Pointer(to=first), Pointer(to=second)), List[Int]([1]))
    try:
        _ = run[I](pending^, 8)
    except error:
        pass
