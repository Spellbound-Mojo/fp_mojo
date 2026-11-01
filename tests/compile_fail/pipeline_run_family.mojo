# error: no matching
from fp.functions import pipeline
from fp.effects import Reader, State
def main(): _ = pipeline[State[Int]](Reader[Int].pure(3)).run(0)
