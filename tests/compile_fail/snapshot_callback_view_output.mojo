# error: no matching function
from fp.functions import partial
from fp.iteration import scan_left
def step(bias: Int, carry: Int, item: Int) -> Tuple[Int, Int]: return (carry + bias, item)
def main():
    var callback = partial(step, 0)
    _ = scan_left(callback, 0, range(2))
