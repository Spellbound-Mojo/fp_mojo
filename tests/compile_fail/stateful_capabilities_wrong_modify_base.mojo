# error: constraint
from fp.effects import State, StateT, LiftStateful, put
def main():
    _ = put[LiftStateful[StateT[State[String], Int], State[Int]]](1)
