# error: no matching method
from fp.functions import pipeline
def logical(var value: Int) -> SIMD[DType.bool,1]: return SIMD[DType.bool,1](value > 0)
def main(): _ = pipeline(range(3)).sum_by(logical).get()
