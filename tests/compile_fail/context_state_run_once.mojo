# error: no matching function in call to 'run'
from context_state_run_support import Once
from fp.effects import State, run

def main():
    comptime I = State[Int]
    var pending = I.collect(Once(), List[Int]([1]))
    _ = run[I](pending^, 8)
