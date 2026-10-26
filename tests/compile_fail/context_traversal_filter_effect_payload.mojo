# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily
def callback(value: Int) -> Optional[Int]: return Optional(value)
def main(): _ = pipeline(List[Int]([1])).filter_effect[OptionalFamily](callback).get()
