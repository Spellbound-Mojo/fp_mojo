# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Ok
def callback(var value: Int) -> Result[List[Int], Int]: return Ok(List[Int]([value]))
def main(): _ = pipeline(List[Int]([1])).flat_traverse[ResultFamily[String]](callback).get()
