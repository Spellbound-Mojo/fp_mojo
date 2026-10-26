# error: violated constraint
from fp.functions import pipeline
from fp.algebra import StringMonoid
def main(): _ = pipeline(range(3)).combine_all[StringMonoid]().get()
