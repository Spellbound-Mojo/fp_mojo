# error: no matching function
from fp.functions import partial
from fp.iteration import scan_map
def step(bias: Int, carry: Int) -> Tuple[Int, Int]: return (carry, bias)
def main():
    var callback = partial(step, 0)
    _ = scan_map(callback, 0, range(2))
