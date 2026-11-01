# error: no matching function
from fp.functions import partial
from fp.iteration import zip_with
def unary(bias: Int, value: Int) -> Int: return bias + value
def main():
    var callback = partial(unary, 0)
    _ = zip_with(range(2), range(2), callback)
