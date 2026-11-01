# error: no matching
from fp.functions import pipeline
from fp.effects import State
def change(value: Int) -> Int: return value + 1
def main(): _ = pipeline(State[Int].pure(3)).local(change)
