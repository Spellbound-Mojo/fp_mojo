# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily
def callback(var value: String) -> Optional[Bool]: return Optional(True)
def main():
    var pointer: def(var String) thin -> Optional[Bool] = callback
    _ = pipeline(List[String](["value"])).traverse_tap[OptionalFamily](pointer).get()
