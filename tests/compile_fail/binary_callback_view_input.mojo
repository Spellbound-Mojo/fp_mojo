# error: no matching function
from fp.functions import partial
from fp.iteration import zip_with
def combine(bias: Int, first: String, second: Int) -> Int:
    return bias + len(first) + second
def main():
    var callback = partial(combine, 0)
    _ = zip_with(callback, range(2), range(2))
