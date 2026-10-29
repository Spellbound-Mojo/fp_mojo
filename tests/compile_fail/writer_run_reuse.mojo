# error: use of uninitialized value
from fp.effects import Writer, run, run_writer
from fp.algebra import StringMonoid
def main():
    comptime W = Writer[StringMonoid]
    var value = W.pure(7)
    _ = run[W](value^)
    _ = run_writer[W](value^)
