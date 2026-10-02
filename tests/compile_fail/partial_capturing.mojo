# error: no matching function in call to 'partial'
# error: cannot be converted from 'def(a: Int, b: Int) -> Int'
# A capturing closure already binds its captures; it cannot be a partial target.
from fp.functions import partial
def main():
    var offset = 3
    def shifted(a: Int, b: Int) {offset} -> Int:
        return a + b + offset
    _ = partial(shifted, 1)
