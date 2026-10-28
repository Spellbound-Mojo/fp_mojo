# error: no matching function
from fp.functions import merge
def good(var value: Int) -> Int: return value+1
def main(): _ = merge(bad, good)
def bad(mut a: Int) -> Int: return a
