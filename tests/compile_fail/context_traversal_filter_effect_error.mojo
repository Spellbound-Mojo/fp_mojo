# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily
def callback(value: Int) raises String -> Optional[Bool]: raise String("wrong")
def main() raises Int: _ = pipeline(List[Int]([1])).raising[Int]().filter_effect[OptionalFamily](callback).get()
