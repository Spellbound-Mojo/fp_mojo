# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily, StringMonoid, ValidationFamily, ListMonoid
from fp.data import Result, Ok
def callback(var acc: Int, var value: Int) -> Result[Int, Int]: return Ok(value)
def main(): _ = pipeline(List[Int]([1])).fold_effect[ResultFamily[String]](0).run(callback).get()
