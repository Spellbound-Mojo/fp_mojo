# error: no matching value in call to '__call__'
from fp.functions import merge
def increment(var value: Int) -> Int: return value + 1
def main(): _ = merge(increment, increment)(String("bad"))
