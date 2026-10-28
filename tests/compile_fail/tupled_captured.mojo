# error: no matching function in call to 'tupled'
from fp.functions import tupled
def main():
    var offset = 1
    def native(var first: Int, var second: Int) {offset} -> Int: return first + second + offset
    _ = tupled(native)
