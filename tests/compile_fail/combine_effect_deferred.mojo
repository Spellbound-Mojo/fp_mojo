# error: no matching
from fp.functions import pipeline
from fp.algebra import StringMonoid
from fp.effects import Reader
def main() raises:
    _ = pipeline(List[Reader[Int].Pure[Int]]()).combine_all_effect[StringMonoid]()
