# error: use of uninitialized value 'native'
from fp.callables import BinarySignature
@fieldwise_init
struct Key(Movable):
    var value: Int
def main():
    var key = Key(1)
    def native(var first: Int, var second: Int) {var key^} -> Int: return first + second + key.value
    var callback = BinarySignature[Int, Int, Int].capture(native^)
    _ = native(1, 2)
    _ = callback(1, 2)
