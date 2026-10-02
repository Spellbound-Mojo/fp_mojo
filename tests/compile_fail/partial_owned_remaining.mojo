# error: no matching function in call to 'partial'
# error: cannot be converted from 'def twice(var x: Int) thin -> Int'
# Remaining arguments are borrowed, so an owned remaining parameter needs a
# closure; binding it instead (partial(twice, x)) is supported.
from fp.functions import partial
def twice(var x: Int) -> Int:
    return x * 2
def main():
    _ = partial(twice)
