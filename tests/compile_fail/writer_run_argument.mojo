# error: no matching
from fp.effects import Writer, run
from fp.algebra import StringMonoid
def main():
    comptime W = Writer[StringMonoid]
    _ = run[W](W.pure(7),0)
