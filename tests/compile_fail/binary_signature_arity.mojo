# error: no matching function in call to 'capture'
from fp.callables import BinarySignature
def bad(var first: Int) -> Int: return first
def main(): _ = BinarySignature[Int, Int, Int].capture(bad)
