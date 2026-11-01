# error: no matching function in call to 'capture'
from fp.callables import BinarySignature
def main():
    var offset = 1
    def bad(mut first: Int, second: Int) {offset} -> Int: return first + second + offset
    _ = BinarySignature[Int, Int, Int].capture(bad)
