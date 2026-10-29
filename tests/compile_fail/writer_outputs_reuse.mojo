# error: use of uninitialized value
from fp.functions import pipeline
from fp.effects import Writer
from fp.algebra import StringMonoid
def main():
    var pending = pipeline(Writer[StringMonoid].pure(7))
    _ = pending^.run_value()
    _ = pending^.run_log()
