# error: no matching
from fp.effects import Writer, run
from fp.algebra import StringMonoid, IntSumMonoid
def main(): _ = run[Writer[StringMonoid]](Writer[IntSumMonoid].pure(7))
