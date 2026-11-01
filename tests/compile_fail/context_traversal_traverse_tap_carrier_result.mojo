# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily
def callback(value: Int) -> Int: return value
def main(): _ = pipeline(List[Int]([1])).traverse_tap[ResultFamily[String]](callback).get()
