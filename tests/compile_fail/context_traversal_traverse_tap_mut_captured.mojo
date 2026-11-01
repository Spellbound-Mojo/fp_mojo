# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily
def main() raises Int:
    var calls = 0
    def callback(mut value: String) raises Int {mut calls} -> Optional[Bool]:
        calls += 1
        return Optional(True)
    _ = pipeline(List[String](["value"])).raising[Int]().traverse_tap[OptionalFamily](callback).get()
