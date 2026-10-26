# error: no matching method
# error: CarrierCompatible
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily
def callback(value: Int) -> Int: return value
def main(): _ = pipeline(List[Int]([1])).filter_effect[OptionalFamily](callback).get()
