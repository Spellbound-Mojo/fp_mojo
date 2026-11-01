# error: no matching
from fp.functions import pipeline
def callback(value: String) -> Optional[Bool]: return Optional(True)
def main() raises:
    _ = pipeline(List[Int]([1])).find_effect(callback)
