# error: cannot call function that may raise
from fp.iteration import iterated
def callback(var value: Int) raises Int -> Optional[Int]: raise value
def main() raises: _ = iterated(range(2)).traverse_void(callback)
