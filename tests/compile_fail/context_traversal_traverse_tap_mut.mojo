# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily
def callback(mut value: String) raises Int -> Optional[Bool]:
    return Optional(True)
def main() raises Int:
    _ = pipeline(List[String](["value"])).raising[Int]().traverse_tap[OptionalFamily](callback).get()
