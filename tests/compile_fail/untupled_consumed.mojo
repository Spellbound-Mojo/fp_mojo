# error: use of uninitialized value 'callback'
from fp.functions import untupled
def total(var pair: Tuple[Int, Int]) -> Int: return pair[0] + pair[1]
def main():
    var callback = untupled(total)
    _ = callback^.call_once(1, 2)
    _ = callback(3, 4)
