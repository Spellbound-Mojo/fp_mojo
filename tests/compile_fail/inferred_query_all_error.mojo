# error: no matching
from fp.functions import pipeline
def callback(value: Int) raises Int -> Optional[Bool]: raise value
def main() raises:
    _ = pipeline(List[Int]([1])).raising[String]().all_effect(callback)
