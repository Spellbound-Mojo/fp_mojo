# error: cannot be implicitly copied
from fp.callables import BinarySignature
@fieldwise_init
struct Key(Movable):
    var value: Int
def main():
    var key = Key(1)
    def native(var first: Int, var second: Int) {var key^} -> Int: return first + second + key.value
    _ = BinarySignature[Int, Int, Int].capture(native)
