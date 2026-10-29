# error: no matching
from fp.functions import pipeline
from fp.effects import State
def main(): _ = pipeline(State[Int].pure(3)).run(String("bad"))
