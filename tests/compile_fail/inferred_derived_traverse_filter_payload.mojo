# error: no matching
from fp.functions import pipeline
def callback(var value: Int) -> Optional[Int]: return Optional(value)
def main() raises:
    _ = pipeline(List[Int]([1])).traverse_filter(callback)
