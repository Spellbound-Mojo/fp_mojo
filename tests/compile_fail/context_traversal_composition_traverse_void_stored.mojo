# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Ok
def callback(var value: Int) -> Result[Int, Int]: return Ok(value)
def main(): _ = pipeline(List[Int]([1])).traverse_void[ResultFamily[String]](callback).get()
