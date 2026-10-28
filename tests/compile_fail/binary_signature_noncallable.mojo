# error: no matching function in call to 'capture'
from fp.callables import BinarySignature
def main(): _ = BinarySignature[Int, Int, Int].capture(42)
