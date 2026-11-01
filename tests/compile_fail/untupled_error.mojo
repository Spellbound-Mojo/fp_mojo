# error: cannot call function that may raise
from fp.functions import untupled
def fail(var pair: Tuple[Int, Int]) raises Int -> Int: raise pair[0]
def main() raises: _ = untupled(fail)(1, 2)
