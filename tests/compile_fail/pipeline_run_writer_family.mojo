# error: no matching
from fp.functions import pipeline
from fp.effects import Writer
from fp.algebra import StringMonoid, IntSumMonoid
def main(): _ = pipeline[Writer[IntSumMonoid]](Writer[StringMonoid].pure(3)).run()
