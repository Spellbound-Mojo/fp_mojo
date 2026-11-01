# error: no matching
from fp.effects import Writer, run_value
from fp.algebra import StringMonoid, IntSumMonoid
def main(): _ = run_value[Writer[StringMonoid]](Writer[IntSumMonoid].pure(7))
