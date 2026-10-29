# error: use of uninitialized value
from fp.functions import pipeline
from fp.effects import State
def main():
    var pending = pipeline(State[Int].pure(7))
    _ = pending^.run_value(0)
    _ = pending^.run_state(0)
