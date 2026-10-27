# error: no matching
from fp.functions import pipeline
from fp.algebra import StringMonoid, OptionalFamily, ResultFamily, ValidationFamily, ListMonoid
from fp.data import Result
from fp.effects import Reader
def main() raises:
    _ = pipeline(List[Reader[Int].Pure[String]]()).combine_all_effect[StringMonoid]()
