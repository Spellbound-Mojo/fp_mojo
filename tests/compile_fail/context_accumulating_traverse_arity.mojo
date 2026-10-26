# error: no matching method
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.algebra import StringMonoid
def bad()->Result[Int,List[String]]: return Ok(1)
def main(): _ = pipeline(List[Int]([1])).par_traverse(bad).get()
