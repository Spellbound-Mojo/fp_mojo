# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily, StringMonoid, ValidationFamily, ListMonoid
from fp.data import Result, Ok
def callback(value: Int) -> Optional[Bool]: return Optional(True)
def main(): _ = pipeline(List[Int]([1])).any_effect[ValidationFamily[ListMonoid[String]]](callback).get()
