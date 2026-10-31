# error: no matching
from fp.functions import pipeline
def checked(var value: Int) raises Int -> Optional[Int]: raise value
def main() raises:
    _ = pipeline(List[Int]([1])).raising[String]().traverse(checked)
