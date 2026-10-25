# error: no matching method in call to 'traverse'
from fp.functions import pipeline
from fp.algebra import ResultFamily
from fp.data import Result, Ok
def wrong(var x: Int) -> Result[Int, Int]: return Ok(x)
def main(): _ = pipeline(List[Int]([1])).traverse[ResultFamily[String]](wrong).get()
