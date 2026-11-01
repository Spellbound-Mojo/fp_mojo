# error: invalid call to 'run_state'
from fp.functions import pipeline
from fp.effects import Reader
def main(): _ = pipeline(Reader[Int].pure(7)).run_state(0)
