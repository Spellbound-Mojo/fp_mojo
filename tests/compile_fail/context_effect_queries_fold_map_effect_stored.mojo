# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily, StringMonoid, ValidationFamily, ListMonoid
from fp.data import Result, Ok
def callback(var value: Int) -> Result[String, Int]: return Ok(String(value))
def main(): _ = pipeline(List[Int]([1])).fold_map_effect[ResultFamily[String],StringMonoid](callback).get()
