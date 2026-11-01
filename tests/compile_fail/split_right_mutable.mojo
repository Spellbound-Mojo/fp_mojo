# error: no matching function
from fp.functions import split
def good(var value: Int) -> Int: return value+1
def main(): _ = split(good, bad)
def bad(mut a: Int) -> Int: return a
