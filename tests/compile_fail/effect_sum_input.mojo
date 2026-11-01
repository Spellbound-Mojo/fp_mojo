# error: no matching
from fp.functions import pipeline
def project(var x: String) -> Optional[Int]: return Optional(x.byte_length())
def main() raises:
    _ = pipeline(List[Int]([1])).sum_by_effect(project)
