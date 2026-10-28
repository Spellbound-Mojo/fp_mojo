# error: constraint failed: partial: remaining argument types and arity must match
from fp.functions import partial

def add3(first: Int, second: Int, third: Int) -> Int: return first + second + third
def main():
    var binary = partial(add3, 1)
    _ = binary.call(2)
