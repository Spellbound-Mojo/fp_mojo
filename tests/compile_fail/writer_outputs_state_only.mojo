# error: invalid call to 'run_state'
from fp.functions import pipeline
from fp.effects import Writer
from fp.algebra import StringMonoid
def main(): _ = pipeline(Writer[StringMonoid].pure(7)).run_state(0)
