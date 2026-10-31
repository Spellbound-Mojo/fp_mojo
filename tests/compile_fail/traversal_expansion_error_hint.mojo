# error: no matching method in call to 'filter_effect'
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ListFamily
def check(value: Int) raises String -> Optional[Bool]: raise String("failure")
def main() raises:
    var xs: List[Int] = [1]
    _ = pipeline(xs^).raising[Int]().filter_effect[OptionalFamily](check)
