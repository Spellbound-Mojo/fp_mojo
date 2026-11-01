# error: no matching
from fp.functions import pipeline
def callback(var value: Int) -> Int: return value
def main() raises:
    _ = pipeline(List[Int]([1])).traverse_void(callback)
