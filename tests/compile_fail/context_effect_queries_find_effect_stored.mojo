# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily, StringMonoid, ValidationFamily, ListMonoid
from fp.data import Result, Ok
def callback(value: Int) -> Result[Bool, Int]: return Ok(True)
def main(): _ = pipeline(List[Int]([1])).find_effect[ResultFamily[String]](callback).get()
