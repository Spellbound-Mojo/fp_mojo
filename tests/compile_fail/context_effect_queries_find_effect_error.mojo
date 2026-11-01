# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily, StringMonoid, ValidationFamily, ListMonoid
from fp.data import Result, Ok
def callback(value: Int) raises String -> Optional[Bool]: raise String("native")
def main(): _ = pipeline(List[Int]([1])).raising[Int]().find_effect[OptionalFamily](callback).get()
