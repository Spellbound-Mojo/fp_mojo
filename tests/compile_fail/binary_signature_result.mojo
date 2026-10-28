# error: no matching function in call to 'capture'
from fp.callables import BinarySignature
def bad(var first: Int, var second: Int) -> String: return String(first + second)
def main(): _ = BinarySignature[Int, Int, Int].capture(bad)
