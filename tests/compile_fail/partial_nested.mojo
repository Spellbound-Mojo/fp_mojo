# error: no matching function in call to 'partial'
# error: cannot be converted from 'Partial[
# Nested partials are not supported; bind both arguments in one partial.
from fp.functions import partial
def add3(a: Int, b: Int, c: Int) -> Int:
    return a + b + c
def main():
    _ = partial(partial(add3, 1), 2)
