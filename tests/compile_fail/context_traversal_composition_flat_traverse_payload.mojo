# error: List callback required
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Ok
def callback(var value: Int) -> Optional[Optional[Int]]: return Optional(Optional(value))
def main(): _ = pipeline(List[Int]([1])).flat_traverse[OptionalFamily](callback).get()
