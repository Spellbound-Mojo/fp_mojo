# error: no matching function in call to 'tupled'
from fp.functions import tupled
def bad(mut first: Int, second: Int) -> Int: return first + second
def main(): _ = tupled(bad)
