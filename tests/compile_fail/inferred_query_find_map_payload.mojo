# error: no matching
from fp.functions import pipeline
def callback(var value: Int) -> Optional[Int]: return Optional(value)
def main() raises:
    _ = pipeline(List[Int]([1])).find_map_effect(callback)
