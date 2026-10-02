# error: no matching function in call to 'partial'
# error: unexpected argument
# At most eight arguments can be bound; write a closure for more.
from fp.functions import partial
def sum9(a: Int, b: Int, c: Int, d: Int, e: Int, f: Int, g: Int, h: Int, i: Int) -> Int:
    return a + b + c + d + e + f + g + h + i
def main():
    _ = partial(sum9, 1, 2, 3, 4, 5, 6, 7, 8, 9)
