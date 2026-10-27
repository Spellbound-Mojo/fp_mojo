# error: no matching
from fp.functions import pipeline
from fp.algebra import StringMonoid, OptionalFamily, ResultFamily, ValidationFamily, ListMonoid
from fp.data import Result
@fieldwise_init
struct Owner(Movable):
    var id: Int
def main() raises:
    _ = pipeline(List[List[List[Owner]]]()).combine_all_effect[ListMonoid[Owner]]()
