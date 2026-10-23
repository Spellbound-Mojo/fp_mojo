# error: constraint
from fp.functions import piped
from fp.algebra import OptionalFamily, ListFamily
def check(value: Int) raises String -> Optional[Bool]: raise String("failure")
def main() raises:
    var xs: List[Int] = [1]
    _ = piped(xs^).filter_effect[OptionalFamily, E=String, X=Int](check)
