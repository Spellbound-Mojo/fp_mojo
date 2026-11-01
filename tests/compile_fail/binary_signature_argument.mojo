# error: no matching function in call to 'capture'
from fp.callables import BinarySignature
def bad(var first: String, var second: Int) -> Int: return first.byte_length() + second
def main(): _ = BinarySignature[Int, Int, Int].capture(bad)
