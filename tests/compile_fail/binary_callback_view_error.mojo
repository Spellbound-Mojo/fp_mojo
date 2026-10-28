# error: no matching method
from fp.functions import partial
from fp.iteration import iterated
def combine(bias: Int, first: Int, second: Int) raises Int -> Int:
    raise bias + first + second
def main():
    var callback = partial(combine, 0)
    _ = iterated(range(2)).zip_with(range(2), callback)
