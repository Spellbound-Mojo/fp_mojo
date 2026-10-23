# error: constraint
from fp.effects import State, StateT, LiftStateful, get
def main():
    _ = get[LiftStateful[StateT[State[String], Int], State[Int]]]()
