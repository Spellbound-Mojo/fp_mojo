# error: no matching
from fp.functions import pipeline
def project(var x: Int) -> Optional[SIMD[DType.bool, 4]]: return Optional(SIMD[DType.bool, 4](True))
def main() raises:
    _ = pipeline(List[Int]([1])).sum_by_effect(project)
