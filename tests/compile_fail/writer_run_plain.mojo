# error: no matching
from fp.effects import Writer, run
from fp.algebra import StringMonoid
def main(): _ = run[Writer[StringMonoid]](7)
