# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Ok
def callback(var value: Int) -> Result[Optional[Int], Int]: return Ok(Optional(value))
def main(): _ = pipeline(List[Int]([1])).traverse_filter[ResultFamily[String]](callback).get()
