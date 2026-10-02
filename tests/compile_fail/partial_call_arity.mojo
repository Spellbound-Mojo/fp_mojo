# error: expected 2 elements in variadic pack, got 1 argument value
# The remaining arguments are checked like a direct call.
from fp.functions import partial
def add3(a: Int, b: Int, c: Int) -> Int:
    return a + b + c
def main():
    var p = partial(add3, 1)
    _ = p(2)
