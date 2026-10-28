# error: no matching function in call to 'tupled'
from fp.functions import tupled
def three(first: Int, second: Int, third: Int) -> Int: return first + second + third
def main(): _ = tupled(three)
