# error: violated constraint
from fp.effects import State, run_state
def main(): _ = run_state[State[Int]](State[String].pure(7),0)
