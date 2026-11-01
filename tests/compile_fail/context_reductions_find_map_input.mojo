# error: no matching method
from fp.functions import pipeline
from fp.algebra import StringMonoid
def bad(var value: String) -> Optional[Int]: return Optional(1)
def main():
    _ = pipeline(List[Int]([1])).find_map(bad).get()
