# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Ok
def callback(var value: Int) raises String -> Optional[Int]: raise String("wrong")
def main(): _ = pipeline(List[Int]([1])).raising[Int]().traverse_void[OptionalFamily](callback).get()
