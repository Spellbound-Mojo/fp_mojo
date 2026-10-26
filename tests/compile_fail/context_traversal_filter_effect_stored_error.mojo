# error: no matching method
from fp.functions import pipeline
from fp.algebra import ResultFamily
from fp.data import Result, Ok
def callback(value: Int) -> Result[Bool,Int]: return Ok(True)
def main(): _ = pipeline(List[Int]([1])).filter_effect[ResultFamily[String]](callback).get()
