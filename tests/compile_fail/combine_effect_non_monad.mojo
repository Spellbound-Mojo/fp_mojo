# error: no matching
from fp.functions import pipeline
from fp.algebra import StringMonoid, OptionalFamily, ResultFamily, ValidationFamily, ListMonoid
from fp.data import Result
def main() raises:
    _ = pipeline(List[Result[String, List[String]]]()).combine_all_effect[ValidationFamily[ListMonoid[String]], StringMonoid]()
