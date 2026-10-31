# error: no matching
from fp.functions import pipeline
def project(var x: Int) raises Int -> Optional[Int]: raise x
def main() raises:
    _ = pipeline(List[Int]([1])).raising[String]().sum_by_effect(project)
