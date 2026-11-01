# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Ok
def callback(mut value: Int) -> Optional[Int]: return Optional(value)
def main(): _ = pipeline(List[Int]([1])).traverse_void[OptionalFamily](callback).get()
