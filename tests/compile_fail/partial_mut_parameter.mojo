# error: no matching function in call to 'partial'
# error: cannot be converted from 'def bump(mut counter: Int, step: Int) thin -> Int'
# Bound values are passed as fresh owned copies; a mut parameter cannot take one.
from fp.functions import partial
def bump(mut counter: Int, step: Int) -> Int:
    counter += step
    return counter
def main():
    _ = partial(bump, 10)
