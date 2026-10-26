# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily
from fp.data import Result, Ok
def callback(var value: Int) -> Optional[Optional[Int]]: return Optional(Optional(value))
def main(): _ = pipeline(Result[Int,String](Ok(1))).traverse_filter[OptionalFamily](callback).get()
