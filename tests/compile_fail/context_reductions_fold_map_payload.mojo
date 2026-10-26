# error: no matching method
from fp.functions import pipeline
from fp.algebra import StringMonoid
def bad(var value: Int) -> Int: return value
def main(): _ = pipeline(range(3)).fold_map[StringMonoid](bad).get()
