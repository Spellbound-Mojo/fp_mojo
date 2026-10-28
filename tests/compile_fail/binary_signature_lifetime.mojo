# error: use of uninitialized value 'callback'
from fp.callables import BinarySignature
from fp.iteration import iterated
def main():
    var offset = 1
    def native(var first: Int, var second: Int) {offset} -> Int: return first + second + offset
    var callback = BinarySignature[Int, Int, Int].capture(native)
    var pending = iterated(range(2)).zip_with(range(2), callback)
    var extracted = callback^.into_function()
    _ = extracted(1, 2)
    _ = pending^.collect_list()
