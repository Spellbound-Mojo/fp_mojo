# error: no matching
from fp.functions import pipeline
from fp.effects import Writer
from fp.algebra import StringMonoid
def bad(var value: String) -> Int: return value.byte_length()
def main(): _ = pipeline(Writer[StringMonoid].pure(3)).censor(bad)
