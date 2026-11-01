# error: no matching function
from fp.functions import partial
from fp.iteration import scan_left
def step(bias: Int, carry: Int) -> Int: return carry + bias
def main():
    var callback = partial(step, 0)
    _ = scan_left(range(2), 0, callback)
