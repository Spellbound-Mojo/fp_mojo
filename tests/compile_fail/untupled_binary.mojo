# error: no matching function in call to 'untupled'
from fp.functions import untupled
def bad(first: Int, second: Int) -> Int: return first + second
def main(): _ = untupled(bad)
