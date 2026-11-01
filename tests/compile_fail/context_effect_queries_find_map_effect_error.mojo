# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily, StringMonoid, ValidationFamily, ListMonoid
from fp.data import Result, Ok
def callback(var value: Int) raises String -> Optional[Optional[Int]]: raise String("native")
def main(): _ = pipeline(List[Int]([1])).raising[Int]().find_map_effect[OptionalFamily](callback).get()
