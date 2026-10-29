# error: invalid call to 'run_value'
from fp.functions import pipeline
from fp.effects import State
def main(): _ = pipeline(State[Int].pure(7)).run_value(String("wrong"))
