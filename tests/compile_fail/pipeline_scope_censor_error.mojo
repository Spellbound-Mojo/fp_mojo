# error: no matching
from fp.functions import pipeline
from fp.effects import Writer
from fp.algebra import StringMonoid
def bad(var value: String) raises Int -> String: raise 1
def main() raises: _ = pipeline(Writer[StringMonoid].pure(3)).raising[String]().censor(bad)
