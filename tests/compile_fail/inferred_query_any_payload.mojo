# error: no matching
from fp.functions import pipeline
def callback(value: Int) -> Optional[Int]: return Optional(value)
def main() raises:
    _ = pipeline(List[Int]([1])).any_effect(callback)
