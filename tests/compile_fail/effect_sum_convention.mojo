# error: no matching
from fp.functions import pipeline
def project(mut x: Int) -> Optional[Int]: return Optional(x)
def main() raises:
    _ = pipeline(List[Int]([1])).sum_by_effect(project)
