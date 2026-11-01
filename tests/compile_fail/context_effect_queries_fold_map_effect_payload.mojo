# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily, StringMonoid, ValidationFamily, ListMonoid
from fp.data import Result, Ok
def callback(var value: Int) -> Optional[Int]: return Optional(1)
def main(): _ = pipeline(List[Int]([1])).fold_map_effect[StringMonoid,OptionalFamily](callback).get()
