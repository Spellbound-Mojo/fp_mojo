# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily, StringMonoid, ValidationFamily, ListMonoid
from fp.data import Result, Ok
def callback(var value: String) -> Optional[Optional[Int]]: return Optional(Optional(1))
def main(): _ = pipeline(List[Int]([1])).find_map_effect[OptionalFamily](callback).get()
