# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily
def callback(value: Int) -> Optional[Bool]: return Optional(True)
def main(): _ = pipeline(List[String](["value"])).traverse_tap[OptionalFamily](callback).get()
