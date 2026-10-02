# error: no matching function in call to 'partial'
# error: cannot be converted from 'String' to 'Int'
# A bound value must have the target parameter's type.
from fp.functions import partial
def add(a: Int, b: Int) -> Int:
    return a + b
def main():
    _ = partial(add, String("one"))
