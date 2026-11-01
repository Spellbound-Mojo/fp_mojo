# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Ok
def callback(var value: Int) raises String -> Optional[List[Int]]: raise String("wrong")
def main(): _ = pipeline(List[Int]([1])).raising[Int]().flat_traverse[OptionalFamily](callback).get()
