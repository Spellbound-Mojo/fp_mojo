# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Ok
def callback(var value: Int, extra: Int) -> Optional[List[Int]]: return Optional(List[Int]([value]))
def main(): _ = pipeline(List[Int]([1])).flat_traverse[OptionalFamily](callback).get()
