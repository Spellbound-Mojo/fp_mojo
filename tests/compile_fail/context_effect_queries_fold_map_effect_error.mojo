# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily, StringMonoid, ValidationFamily, ListMonoid
from fp.data import Result, Ok
def callback(var value: Int) raises String -> Optional[String]: raise String("native")
def main(): _ = pipeline(List[Int]([1])).raising[Int]().fold_map_effect[OptionalFamily,StringMonoid](callback).get()
