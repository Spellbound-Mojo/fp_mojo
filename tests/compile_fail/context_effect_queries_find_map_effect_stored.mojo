# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily, StringMonoid, ValidationFamily, ListMonoid
from fp.data import Result, Ok
def callback(var value: Int) -> Result[Optional[Int], Int]: return Ok(Optional(value))
def main(): _ = pipeline(List[Int]([1])).find_map_effect[ResultFamily[String]](callback).get()
