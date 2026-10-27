# error: no matching
from fp.functions import pipeline
def project(var x: Int) -> Optional[String]: return Optional(String(x))
def main() raises:
    _ = pipeline(List[Int]([1])).sum_by_effect(project)
