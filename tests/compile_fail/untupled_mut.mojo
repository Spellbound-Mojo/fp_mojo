# error: no matching function in call to 'untupled'
from fp.functions import untupled
def bad(mut value: Tuple[Int, Int]) -> Int: return value[0]
def main(): _ = untupled(bad)
