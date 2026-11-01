# error: no matching method
from fp.functions import partial
from fp.iteration import iterated
def step(bias: Int, carry: Int, item: Int) raises Int -> Tuple[Int, Int]: raise bias + carry + item
def main():
    var callback = partial(step, 0)
    _ = iterated(range(2)).scan_map(callback, 0)
