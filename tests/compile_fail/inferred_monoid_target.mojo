# error: no matching
from fp.functions import pipeline
from fp.algebra import StringMonoid
def callback(var value: Int) -> String: return String(value)
def main() raises:
    _ = pipeline(List[Int]([1])).fold_map_effect[StringMonoid](callback)
