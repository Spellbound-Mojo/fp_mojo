# error: no matching function in call to 'untupled'
from fp.functions import untupled
def bad(var value: Int) -> Int: return value
def main(): _ = untupled(bad)
