# error: no matching function in call to 'partial'
# error: unexpected keyword argument 'factor'
# Keyword binding is written as a native closure.
from fp.functions import partial
def scale(x: Int, factor: Int) -> Int:
    return x * factor
def main():
    _ = partial(scale, factor=2)
