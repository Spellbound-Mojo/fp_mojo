# error: no matching function in call to 'capture'
from fp.callables import BinarySignature
def bad(mut first: Int, second: Int) -> Int: return first + second
def main(): _ = BinarySignature[Int, Int, Int].capture(bad)
