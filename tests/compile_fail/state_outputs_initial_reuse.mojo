# error: use of uninitialized value
from fp.effects import State, run_value
def main():
    var initial = String("state")
    _ = run_value[State[String]](State[String].pure(7),initial^)
    _ = initial.byte_length()
