# error: no matching function in call to 'untupled'
from fp.functions import untupled
def bad(var value: Tuple[Int, Int, Int]) -> Int: return value[0]
def main(): _ = untupled(bad)
