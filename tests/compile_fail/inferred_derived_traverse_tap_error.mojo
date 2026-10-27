# error: no matching
from fp.functions import pipeline
def callback(value: Int) raises Int -> Optional[Int]: raise value
def main() raises:
    _ = pipeline(List[Int]([1])).traverse_tap(callback)
