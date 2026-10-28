# error: cannot be converted
from fp.functions import tupled
def add(first: Int, second: Int) -> Int: return first + second
def main(): _ = tupled(add)((String("one"), 2))
