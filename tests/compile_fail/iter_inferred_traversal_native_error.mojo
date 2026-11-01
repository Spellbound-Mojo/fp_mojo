# error: cannot call function that may raise
# The callback's exact Int error cannot leave a context that raises String.
from fp.iteration import iterated
def callback(var value: Int) raises Int -> Optional[Int]: raise value
def run() raises String: _ = iterated(range(2)).traverse(callback)
def main() raises: run()
