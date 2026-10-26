# error: no matching method
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.algebra import StringMonoid
def bad(var value:Int)->Result[Int,List[String]]: return Ok(value)
def main(): _ = pipeline(List[Int]([1])).par_traverse[StringMonoid](bad).get()
