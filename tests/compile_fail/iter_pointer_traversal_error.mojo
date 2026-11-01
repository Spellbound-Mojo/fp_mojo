# error: cannot call function that may raise
# The plain function's exact Int error cannot leave a context that raises String.
from fp.iteration import iterated
def callback(var value: Int) raises Int -> Optional[Int]: raise value
def run() raises String:
    var pointer: def(var Int) raises Int thin -> Optional[Int] = callback
    _ = iterated(range(2)).traverse(pointer)
def main() raises: run()
