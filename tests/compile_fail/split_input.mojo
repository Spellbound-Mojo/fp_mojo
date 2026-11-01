# error: no matching value
from fp.functions import split
def good(var value: Int) -> Int: return value+1
def main(): _ = split(good, good)((2, String("bad")))
