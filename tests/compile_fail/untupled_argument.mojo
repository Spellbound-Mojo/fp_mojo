# error: no matching value in call
from fp.functions import untupled
def total(var pair: Tuple[Int, Int]) -> Int: return pair[0] + pair[1]
def main(): _ = untupled(total)(1, String("wrong"))
