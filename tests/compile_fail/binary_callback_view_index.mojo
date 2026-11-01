# error: no matching method
from fp.functions import partial
from fp.iteration import iterated
def combine(bias: Int, first: String, second: Int) -> Int:
    return bias + len(first) + second
def main():
    var callback = partial(combine, 0)
    _ = iterated(range(2)).map_with_index(callback)
