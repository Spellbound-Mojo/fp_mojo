# error: no matching
from fp.functions import pipeline
from fp.algebra import StringMonoid
def text(var x: Int) -> String: return String(x)
def main() raises:
    _ = pipeline(List[Int]([1])).fold_map_effect[StringMonoid](text)
