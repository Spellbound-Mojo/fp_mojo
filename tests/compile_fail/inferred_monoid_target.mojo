# error: no matching
from fp.functions import pipeline
from fp.algebra import StringMonoid
from fp.effects import Reader
def callback(var value: Int) -> Reader[Int].Pure[String]: return Reader[Int].pure(String(value))
def main() raises:
    _ = pipeline(List[Int]([1])).fold_map_effect[StringMonoid](callback)
