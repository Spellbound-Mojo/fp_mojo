# error: no matching method
from fp.functions import partial
from fp.iteration import iterated
def step(bias: Int, carry: Int, item: String) -> Int: return carry + bias + len(item)
def main():
    var callback = partial(step, 0)
    _ = iterated(range(2)).scan_left(callback, 0)
