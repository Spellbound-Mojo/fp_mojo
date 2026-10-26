# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily, StringMonoid, ValidationFamily, ListMonoid
from fp.data import Result, Ok
def callback(var acc: Int, var value: Int) raises String -> Optional[Int]: raise String("native")
def main(): _ = pipeline(List[Int]([1])).raising[Int]().fold_effect[OptionalFamily](0).run(callback).get()
