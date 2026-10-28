# error: use of uninitialized value 'callback'
from fp.functions import partial
from fp.iteration import iterated, zip_with
def combine(bias: Int, first: Int, second: Int) -> Int: return bias + first + second
def main():
    var callback = partial(combine, 0)
    var pending = zip_with(callback, range(2), range(2))
    var moved = callback^
    _ = moved(0, 0)
    _ = iterated(pending^).collect_list()
