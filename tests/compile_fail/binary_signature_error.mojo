# error: no matching function in call to 'capture'
from fp.callables import BinarySignature
def bad(var first: Int, var second: Int) raises Int -> Int: raise first + second
def main(): _ = BinarySignature[Int, Int, Int, String].capture(bad)
