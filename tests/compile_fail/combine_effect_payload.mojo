# error: no matching
from fp.functions import pipeline
from fp.algebra import StringMonoid, OptionalFamily, ResultFamily, ValidationFamily, ListMonoid
from fp.data import Result
def main() raises:
    _ = pipeline(List[Optional[Int]]()).combine_all_effect[StringMonoid]()
