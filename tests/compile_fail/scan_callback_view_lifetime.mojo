# error: use of uninitialized value 'callback'
from fp.functions import partial
from fp.iteration import iterated
def step(bias: Int, carry: Int, item: Int) -> Tuple[Int, Int]: return (carry + bias, item)
def main():
    var callback = partial(step, 0)
    var pending = iterated(range(2)).scan_map(callback, 0)
    var moved = callback^
    _ = moved(0, 0)
    _ = pending^.collect_list()
