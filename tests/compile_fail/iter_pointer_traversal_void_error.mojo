# error: cannot call function that may raise
from fp.iteration import iterated
def callback(var value: Int) raises Int -> Optional[Int]: raise value
def main() raises:
    var pointer: def(var Int) raises Int thin -> Optional[Int] = callback
    _ = iterated(range(2)).traverse_void(pointer)
